from __future__ import print_function, unicode_literals
import re
import os
import shutil
import six

from preupg.utils import FileHelper
from preupg.xccdf import XccdfHelper
from preupg import settings
from preupg.settings import ModuleValues
from preupg.logger import logger_report, log_message
try:
    from xml.etree import ElementTree
except ImportError:
    from elementtree import ElementTree
from preupg.xmlgen import xml_tags


def get_node(tree, tag, name_space='', prefix=''):
    return tree.find(prefix + name_space + tag)


def remove_node(tree, tag):
    return tree.remove(tag)


class ReportHelper(object):

    @staticmethod
    def get_needs_inspection():
        return settings.needs_inspection

    @staticmethod
    def get_needs_action():
        return settings.needs_action

    @staticmethod
    def upd_inspection(rule):
        """
        Function updates result to needs_inspection in case
        of SLIGHT or MEDIUM risk
        """
        return rule.get("idref"), ReportHelper.get_needs_inspection()

    @staticmethod
    def upd_action(rule):
        """Function updates result to needs_action in caseof HIGH"""
        return rule.get("idref"), ReportHelper.get_needs_action()

    @staticmethod
    def upd_extreme(rule):
        """Function does no update result for extreme risk"""
        return None, "fail"


class ReportParser(object):

    """Class manipulates with XML files created by oscap"""

    def __init__(self, report_path):
        self.path = report_path
        self.element_prefix = "{http://checklists.nist.gov/xccdf/1.2}"
        try:
            # ElementTree.fromstring can't parse safely unicode string
            content = FileHelper.get_file_content(report_path, 'rb', False, False)
        except IOError:
            raise
        if not content:
            return None
        self.target_tree = ElementTree.fromstring(content)
        self.profile = "Profile"
        self.changed_results = {}
        self.output_data = []

    def filter_children(self, tree, tag):
        return self.get_nodes(tree, tag, prefix='./')

    def has_children(self, tree, tag):
        return len(self.get_nodes(tree, tag, prefix='./')) > 0

    def filter_grandchildren(self, tree, parent_tag, tag):
        return tree.findall('./%s%s/%s%s' % (self.element_prefix,
                                             parent_tag,
                                             self.element_prefix, tag))

    def get_child(self, tree, tag):
        return get_node(tree, tag, self.element_prefix, prefix='./')

    def get_nodes_attrib(self, tree, tag, attrib):
        try:
            return self.get_child(tree, tag).attrib[attrib]
        except (KeyError, AttributeError):
            return ''

    def get_nodes(self, tree, tag, prefix=''):
        return tree.findall(prefix + self.element_prefix + tag)

    def get_nodes_text(self, tree, tag):
        try:
            text = self.get_child(tree, tag).text
        except AttributeError:
            pass
        else:
            if text:
                return text.strip()
        return ''

    def reload_xml(self, path):
        """Function updates self.target_tree with the new path"""
        self.path = path
        # ElementTree.fromstring can't parse safely unicode string
        content = FileHelper.get_file_content(self.path, 'rb', False, False)
        if not content:
            return None
        self.target_tree = ElementTree.fromstring(content)

    def get_select_rules(self):
        selected = self.filter_grandchildren(self.target_tree, self.profile, "select")
        return selected

    def get_allowed_selected_rules(self):
        selected = []
        for sel in self.get_select_rules():
            if sel.get('selected') == 'true':
                selected.append(sel)
        return selected

    def get_number_checks(self):
        """Function returns a number of checkswho are really selected"""
        return len(self.get_allowed_selected_rules())

    def _get_all_rules(self):
        return self.get_nodes(self.target_tree, "Rule", prefix=".//")

    def get_name_of_checks(self):
        """Function returns a names of rules"""
        list_names = {}
        rule_nodes = self._get_all_rules()
        for select in self.get_allowed_selected_rules():
            id_ref = select.get('idref', '')
            rule = [x for x in rule_nodes if x.get('id', '') == id_ref]
            list_names[id_ref] = self.get_nodes_text(rule[0], "title")
        return list_names

    def get_all_result_rules(self):
        """Function returns all rul-result in TestResult xml tag"""
        return self.filter_grandchildren(self.target_tree, "TestResult", "rule-result")

    def get_all_results(self):
        """Function return all results"""
        results = []
        for rule in self.get_all_result_rules():
            results.extend(self.get_nodes(rule, "result", prefix='./'))
        return results

    def get_solution_files(self):
        """
        Function returns a dictionary with solution_files

        Format is:
        xccdf_preupg_backup_solution_file=solution.txt
        """
        dict_solution = {}
        for values in self.get_nodes(self.target_tree, "Value", prefix='.//'):
            value_id = values.get('id')
            if not value_id.endswith("_state_solution_file"):
                continue
            for value in self.get_nodes(values, "value"):
                logger_report.debug(value_id)
                value_id = value_id.replace('xccdf_preupg_value_', '').replace("_state_solution_file", '')
                dict_solution[value_id] = value.text
        logger_report.debug(dict_solution)
        return dict_solution

    def write_xml(self):
        """Function writes XML document to file"""
        self.target_tree.set('xmlns:xhtml', 'http://www.w3.org/1999/xhtml/')
        # we really must set encoding here! and suppress it in write_to_file
        data = ElementTree.tostring(self.target_tree, "utf-8")
        FileHelper.write_to_file(self.path, 'wb', data, False)
        self.target_tree = ElementTree.parse(self.path).getroot()

    def modify_result_path(self, result_dir, scenario, mode):
        """Function modifies result path in XML file"""
        for values in self.get_nodes(self.target_tree, "Value", prefix='.//'):
            if '_current_dir' not in values.get('id'):
                continue
            for value in self.get_nodes(values, "value"):
                logger_report.debug("Replace '%s' with '%s'", value.text, os.path.join(result_dir, scenario))
                value.text = value.text.replace("SCENARIO", os.path.join(result_dir, scenario))

        self.write_xml()

    def modify_platform_tag(self, platform_tag):
        """The function updates platform tag to the assessment system tag"""
        for platform in self.filter_children(self.target_tree, "platform"):
            if "cpe:/o:redhat:enterprise_linux:" in platform.get("idref"):
                logger_report.debug("Update platform tag to '%s'", platform_tag)
                platform.set("idref", "cpe:/o:redhat:enterprise_linux:"+platform_tag)

        self.write_xml()

    def update_inplace_risk(self, scanning_progress, rule, res):
        """Function updates inplace risk"""
        inplace_risk = XccdfHelper.get_check_import_inplace_risk(rule)
        if inplace_risk:
            logger_report.debug("Update_inplace_risk '%s'", inplace_risk)
            return_value = XccdfHelper.get_and_print_inplace_risk(0, inplace_risk)
            logger_report.debug("Get and print inplace risk return value '%s'", return_value)
            if int(return_value)/2 == 1:
                res.text = ReportHelper.get_needs_inspection()
            elif int(return_value)/2 == 2:
                res.text = ReportHelper.get_needs_action()
            for index, row in enumerate(scanning_progress.output_data):
                if self.get_nodes_text(rule, "title") in row:
                    scanning_progress.output_data[index] = "{0}:{1}".format(
                        self.get_nodes_text(rule, "title"),
                        res.text)

    def replace_inplace_risk(self, scanning_results=None):
        """
        This function has aim to replace FAILED to
        NEEDS_INSPECTION in case that risks are SLIGHT or MEDIUM
        """
        #Filter all rule-result in TestResult
        changed_fields = []
        self.remove_empty_check_import()
        inplace_dict = {
            0: ReportHelper.upd_inspection,
            1: ReportHelper.upd_action,
            2: ReportHelper.upd_extreme,
        }
        for rule in self.get_all_result_rules():
            result = [x for x in self.get_nodes(rule, "result") if x.text == "fail"]
            # Get all affected rules and taken their names
            for res in result:
                inplace_risk = XccdfHelper.get_check_import_inplace_risk(rule)
                logger_report.debug(inplace_risk)
                # In case that report has state fail and
                # no log_risk than it should be needs_inspection
                if not inplace_risk:
                    changed = rule.get("idref")
                    res.text = "fail"
                    log_message('The %s module exits as fail but without a risk.' % rule.get("idref"))
                else:
                    inplace_num = XccdfHelper.get_and_print_inplace_risk(0, inplace_risk)
                    logger_report.debug("Call function '%s'", inplace_dict[inplace_num])
                    changed, res.text = inplace_dict[inplace_num](rule)
                    logger_report.debug("Replace text '%s:%s'", changed, res.text)
                if changed is not None:
                    changed_fields.append(changed+":"+res.text)

        if scanning_results:
            scanning_results.update_data(changed_fields)

        self.write_xml()

    def remove_empty_check_import(self):
        """This function remove check_import tag which are empty"""
        for rule in self.get_all_result_rules():
            # Filter all check-import=stdout which are empty and remove them
            for check in self.get_nodes(rule, "check"):
                result = [x for x in self.get_nodes(check, "check-import")
                          if x.get('import-name') == "stdout" and x.text is None]
                if result:
                    for res in result:
                        remove_node(check, res)

    def remove_debug_info(self):
        """Function removes debug information from report"""
        re_expr = r'^preupg.log.DEBUG.*'
        for rule in self.get_all_result_rules():
            for check_import in self.filter_grandchildren(rule,
                                                          "check",
                                                          "check-import"):
                if check_import.text is not None:
                    new_check = []
                    for check in check_import.text.split('\n'):
                        matched = re.match(re_expr, check)
                        if not matched:
                            new_check.append(check)
                    check_import.text = '\n'.join(new_check)
        self.write_xml()

    @staticmethod
    def write_xccdf_version(file_name, direction=False):
        """
        Function updates XCCDF version because
        of separate HTML generation and our own XSL stylesheet
        """
        namespace_1 = 'http://checklists.nist.gov/xccdf/1.1'
        namespace_2 = 'http://checklists.nist.gov/xccdf/1.2'
        content = FileHelper.get_file_content(file_name, "rb")
        if direction:
            content = re.sub(namespace_2, namespace_1, content)
        else:
            content = re.sub(namespace_1, namespace_2, content)
        FileHelper.write_to_file(file_name, 'wb', content)

    def update_check_description(self):
        logger_report.debug("Update check description")
        for rule in self._get_all_rules():
            for description in self.filter_children(rule, 'description'):
                lines = description.text.split('\n')
                details = 'Details:'
                expected_results = 'Expected results:'
                attr = ' xml:lang="en"'
                tag_exp_results = expected_results[:-1].lower().replace(' ', '-')
                tag_details = details[:-1].lower()
                found = 0
                for index, line in enumerate(lines):
                    if line.strip().startswith(details):
                        found = 1
                        lines[index] = line.replace(details, '<ns0:' + tag_details + attr + '>')
                        continue
                    if line.strip().startswith(expected_results):
                        found = 1
                        lines[index] = line.replace(expected_results,
                                                    '</ns0:' + tag_details + '>\n<ns0:' + tag_exp_results + attr + '>')
                        continue
                if found == 1:
                    lines.append('</ns0:' + tag_exp_results + '>')
                    description.text = '\n'.join(lines)
        self.write_xml()

    def select_rules(self, list_rules):
        """
        Function marks choice a specific rules based on the content generation

        :return:
        """
        for select in self.get_select_rules():
            idref = select.get('idref', None)
            logger_report.debug(select)
            logger_report.debug(idref)
            if idref in list_rules:
                select.set('selected', 'true')
            else:
                select.set('selected', 'false')
        self.write_xml()

    def check_rules(self, list_rules):
        """
        Function checks if rules exists
        :param list_rules:
        :return: List of rules which does not exist
        """
        unknown_rules = []
        for select in list_rules:
            found = [i for i in self.get_select_rules() if select in i.get('idref')]
            if not found:
                unknown_rules.append(select)
        return unknown_rules

    def list_rules(self):
        list_rules = []
        for select in self.get_select_rules():
            idref = select.get('idref', None)
            if idref:
                list_rules.append(idref)
        return list_rules

    def get_report_type(self, report_type):
        """
        Function returns all reports for selected report_type

        :param type: specify report_type like 'admin' or 'user'
        :return: a set of content
        """
        if not os.path.exists(self.path):
            return None
        orig_name = self.path
        new_report_name = os.path.join(os.path.dirname(self.path),
                                       settings.result_prefix + '-' + report_type + '.xml')
        shutil.copyfile(self.path, new_report_name)
        self.reload_xml(new_report_name)
        list_dict = {}
        for values in self.get_nodes(self.target_tree, "Value", prefix='.//'):
            values_id = values.get('id')
            if not values_id.endswith('_state_result_part'):
                continue
            for value in self.get_nodes(values, "value"):
                if value.text == report_type:
                    values_id = values_id.replace('_state_result_part', '').replace('xccdf_preupg_value_', '')
                    group_id = '_'.join(values_id.split('_')[:-1])
                    list_dict[group_id] = values_id

        if not list_dict:
            self.reload_xml(orig_name)
            os.unlink(new_report_name)
            return None

        # Remove all reports from TestResult node
        for test_result in self.get_nodes(self.target_tree, 'TestResult'):
            for rule in self.get_nodes(test_result, 'rule-result'):
                idref = rule.get('idref').replace('xccdf_preupg_rule_', '')
                if idref not in list_dict.values():
                    test_result.remove(rule)

        self.write_xml()

        self.reload_xml(orig_name)
        return new_report_name

    def get_path(self):
        """Function return path to report"""
        return self.path

    def add_global_tags(self, result_dir, scenario, mode, devel_mode, dist_native):

        for child in self.get_nodes(self.target_tree, self.profile):
            last_child = child
            for key, val in six.iteritems(xml_tags.GLOBAL_DIC_VALUES):
                if key == 'result_part':
                    continue
                if key == "tmp_preupgrade":
                    val = result_dir
                elif key == "migrate" or key == "upgrade":
                    if not mode or 'migrate' in mode or 'upgrade' in mode:
                        val = "1"
                    else:
                        val = "0"
                elif key == "report_dir":
                    val = os.path.join(result_dir, scenario)
                elif key == "devel_mode":
                    val = str(devel_mode)
                elif key == "dist_native":
                    if dist_native is None:
                        val = "sign"
                    else:
                        val = dist_native
                logger_report.debug("'%s:%s'", key, val)
                new_child = ElementTree.Element(self.element_prefix + 'Value',
                                                {'id': xml_tags.TAG_VALUE + key,
                                                 'type': 'string'
                                                 })
                sub_child = ElementTree.SubElement(new_child, self.element_prefix + 'value')
                sub_child.text = val
                self.target_tree.insert(self.target_tree._children.index(last_child) + 1,
                                        new_child)
        self.write_xml()
