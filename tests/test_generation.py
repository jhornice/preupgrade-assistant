from __future__ import unicode_literals
import unittest
import tempfile
import shutil
# import shlex

import os

from preuputils.compose import XCCDFCompose, ComposeXML
from preuputils import variables
from preup.utils import FileHelper
from preup import settings

try:
    import base
except ImportError:
    import tests.base as base

FOO_DIR = 'FOOBAR'
FOO_RESULTS = FOO_DIR + variables.result_prefix


class TestContentGenerate(base.TestCase):
    dir_name = None

    def tearDown(self):
        if os.path.exists(os.path.join('tests', FOO_RESULTS)):
            shutil.rmtree(os.path.join('tests', FOO_RESULTS))
        for d, subd, file_name in os.walk(self.dir_name):
            group_xml = [x for x in file_name if x == 'group.xml']
            if group_xml:
                os.unlink(os.path.join(d, group_xml[0]))

    def test_compose_with_dir_prefix(self):
        foo_dir = FOO_DIR + '6_7'
        #shutil.copytree(FOO_DIR, os.path.join('tests', foo_dir))
        self.dir_name = os.path.join(os.getcwd(), 'tests', foo_dir, 'dummy')
        foo_results = foo_dir + variables.result_prefix
        result_dir = os.path.join(os.getcwd(), 'tests', foo_results, 'dummy')
        expected_contents = ['failed', 'fixed', 'needs_action', 'needs_inspection', 'not_applicable', 'pass']
        for content in expected_contents:
            compose_xml = ComposeXML()
            result_dir = os.path.join(self.dir_name, content)
            compose_xml.collect_group_xmls(self.dir_name, content=content, generate_from_ini=True)
            self.assertTrue(os.path.exists(os.path.join(result_dir, 'group.xml')))
            self.assertFalse(os.path.exists(os.path.join(result_dir, 'all-xccdf.xml')))

    def test_compose_with_file(self):
        self.dir_name = os.path.join(os.getcwd(), 'tests', FOO_DIR, 'dummy')
        foo_results = FOO_DIR + variables.result_prefix
        result_dir = os.path.join(os.getcwd(), 'tests', foo_results, 'dummy')
        expected_contents = ['failed', 'fixed', 'needs_action', 'needs_inspection', 'not_applicable', 'pass']
        for content in expected_contents:
            compose_xml = ComposeXML()
            result_dir = os.path.join(self.dir_name, content)
            compose_xml.collect_group_xmls(self.dir_name, content=content)
            self.assertTrue(os.path.exists(os.path.join(result_dir, 'group.xml')))
            self.assertFalse(os.path.exists(os.path.join(result_dir, 'all-xccdf.xml')))


class TestGlobalContent(base.TestCase):
    temp_dir = None
    dir_name = None
    result_dir = None

    temp_dir = tempfile.mktemp(prefix='preupgrade', dir='/tmp')
    dir_name = os.path.join(os.getcwd(), 'tests', FOO_DIR)
    result_dir = os.path.join(temp_dir, FOO_DIR + '-results')

    def setUp(self):
        shutil.copytree(self.dir_name, os.path.join(self.temp_dir, FOO_DIR))

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def test_final_compose(self):
        expected_contents = ['failed', 'fixed', 'needs_action', 'needs_inspection', 'not_applicable', 'pass']
        for content in expected_contents:
            compose_xml = ComposeXML()
            dir_name = os.path.join(self.temp_dir, FOO_DIR, 'dummy')
            compose_xml.collect_group_xmls(dir_name, content=content)

        xccdf_compose = XCCDFCompose(os.path.join(self.temp_dir, FOO_DIR))
        xccdf_compose.generate_xml()
        all_xccdf = os.path.join(self.result_dir, settings.content_file)
        self.assertTrue(os.path.exists(all_xccdf))
        dummy_lines = FileHelper.get_file_content(all_xccdf, 'rb')


def suite():
    loader = unittest.TestLoader()
    suite_gen = unittest.TestSuite()
    suite_gen.addTest(loader.loadTestsFromTestCase(TestContentGenerate))
    suite_gen.addTest(loader.loadTestsFromTestCase(TestGlobalContent))
    return suite

if __name__ == '__main__':
    unittest.TextTestRunner(verbosity=3).run(suite())
