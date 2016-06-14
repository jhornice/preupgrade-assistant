
CACHE=/var/cache/preupgrade
PREUPGRADE_CACHE=/var/cache/preupgrade/common
PREUPGRADE_CONFIG=/etc/preupgrade-assistant.conf

VALUE_RPM_QA=$PREUPGRADE_CACHE/rpm_qa.log
PREUPG_RPM_QA=$VALUE_RPM_QA
VALUE_ALL_CHANGED=$PREUPGRADE_CACHE/rpm_Va.log
PREUPG_ALL_CHANGED=$VALUE_ALL_CHANGED
VALUE_CONFIGCHANGED=$PREUPGRADE_CACHE/rpm_etc_Va.log
PREUPG_CONFIGCHANGED=$VALUE_CONFIGCHANGED
VALUE_PASSWD=$PREUPGRADE_CACHE/passwd.log
PREUPG_PASSWD=$VALUE_PASSWD
VALUE_CHKCONFIG=$PREUPGRADE_CACHE/chkconfig.log
PREUPG_CHKCONFIG=$VALUE_CHKCONFIG
VALUE_GROUP=$PREUPGRADE_CACHE/group.log
PREUPG_GROUP=$VALUE_GROUP
VALUE_RPMTRACKEDFILES=$PREUPGRADE_CACHE/rpmtrackedfiles.log
PREUPG_RPMTRACKEDFILES=$VALUE_RPMTRACKEDFILES
VALUE_RPM_RHSIGNED=$PREUPGRADE_CACHE/rpm_rhsigned.log
PREUPG_RPM_RHSIGNED=$VALUE_RPM_RHSIGNED
VALUE_ALLMYFILES=$PREUPGRADE_CACHE/allmyfiles.log
PREUPG_ALLMYFILES=$VALUE_ALLMYFILES
VALUE_EXECUTABLES=$PREUPGRADE_CACHE/executable.log
PREUPG_EXECUTABLES=$VALUE_EXECUTABLES
VALUE_TMP_PREUPGRADE=$XCCDF_VALUE_TMP_PREUPGRADE
PREUPG_TMP_PREUPGRADE=$VALUE_TMP_PREUPGRADE

POSTUPGRADE_DIR=$VALUE_TMP_PREUPGRADE/postupgrade.d
PREUPG_POSTUPGRADE_DIR=$POSTUPGRADE_DIR
CURRENT_DIRECTORY=$XCCDF_VALUE_CURRENT_DIRECTORY
MIGRATE=$XCCDF_VALUE_MIGRATE
UPGRADE=$XCCDF_VALUE_UPGRADE
SOLUTION_FILE=$CURRENT_DIRECTORY/$XCCDF_VALUE_SOLUTION_FILE
KICKSTART_DIR=$VALUE_TMP_PREUPGRADE/kickstart
KICKSTART_README=$KICKSTART_DIR/README
KICKSTART_SCRIPTS=$KICKSTART_DIR/scripts
KICKSTART_POSTUPGRADE=$KICKSTART_SCRIPTS
COMMON_DIR=$XCCDF_VALUE_REPORT_DIR/common
DIST_NATIVE=$XCCDF_VALUE_DIST_NATIVE
DEVEL_MODE=$XCCDF_VALUE_DEVEL_MODE
SPECIAL_PKG_LIST=$KICKSTART_DIR/special_pkg_list
NOAUTO_POSTUPGRADE_D=$VALUE_TMP_PREUPGRADE/noauto_postupgrade.d
RESULT_PASS=$XCCDF_RESULT_PASS
RESULT_FAIL=$XCCDF_RESULT_FAIL
RESULT_FAILED=$RESULT_FAIL
RESULT_ERROR=$XCCDF_RESULT_ERROR
RESULT_UNKNOWN=$XCCDF_RESULT_UNKNOWN
RESULT_NOT_APPLICABLE=$XCCDF_RESULT_NOT_APPLICABLE
RESULT_FIXED=$XCCDF_RESULT_FIXED
RESULT_INFORMATIONAL=$XCCDF_RESULT_INFORMATIONAL
MODULE_NAME=$XCCDF_VALUE_MODULE_NAME

# variables set by PA config file #
HOME_DIRECTORY_FILE=""
USER_CONFIG_FILE=0

PREUPG_API_VERSION=1

export LC_ALL=C

# general logging function
# ------------------------
#
# log SEVERITY [COMPONENT] MESSAGE
#
# @SEVERITY: set it to one of INFO|ERROR|WARNING
# @COMPONENT: optional, relevant RHEL component
# @MESSAGE: message to be logged
#
# Note that if env variable $COMPONENT is defined, it may be omitted from
# parameters.
log()
{
    SEVERITY=$1 ; shift
    if test -z "$COMPONENT"; then
        # only message was passed
        if test "$#" -eq 1; then
            COMPONENT='[unknown]'
        else
            COMPONENT=$1 ; shift
        fi
    else
        if test "$#" -eq 2; then
            shift
        fi
    fi

    echo "$SEVERITY $COMPONENT: $1" >&2
}

log_debug()
{
    log "DEBUG" "$@"
}

log_info()
{
    log "INFO" "$@"
}

log_error()
{
    log "ERROR" "$@"
}

log_warning()
{
    log "WARNING" "$@"
}

log_risk()
{
    echo "INPLACERISK: $1: $2" >&2
}

log_none_risk()
{
    log_risk "NONE" "$1"
}

log_slight_risk()
{
    log_risk "SLIGHT" "$1"
}

log_medium_risk()
{
    log_risk "MEDIUM" "$1"
}

log_high_risk()
{
    log_risk "HIGH" "$1"
}

log_extreme_risk()
{
    log_risk "EXTREME" "$1"
}

exit_unknown()
{
    exit $RESULT_UNKNOWN
}

exit_pass()
{
    exit $RESULT_PASS
}

exit_fail()
{
    exit $RESULT_FAIL
}

exit_error()
{
    exit $RESULT_ERROR
}

exit_not_applicable()
{
    exit $RESULT_NOT_APPLICABLE
}

exit_informational()
{
    exit $RESULT_INFORMATIONAL
}

exit_fixed()
{
    exit $RESULT_FIXED
}

_get_cached_command()
{
    # Function gets a cached command
    # input parameter is command provided by get_cached function
    command=$1
    if [ ! -f "$command" ]; then
        log_error "File $command does not exist. It is mandatory."
    else
        cat $command
    fi
}

get_cached()
{
    # Get general system information from cache
    # Usage:    get_cached file <passwd,group>
    #           get_cached command <rpm_qa, rpm_Va, rpm_etc_Va, chconfig>
    #           get_cached filelist <executable, allmyfiles, rpmrhsignedfiles, rpmtrackedfiles>
    command=$1
    key=$2
    case $command in
        "file")
            case $key in
                "passwd")
                    if [ ! -f "$PREUPG_PASSWD" ]; then
                        log_error "File $PREUPG_PASSWD does not exist. It is mandatory."
                    else
                        cat $PREUPG_PASSWD
                    fi
                    ;;
                "group")
                    if [ ! -f "$PREUPG_GROUP" ]; then
                        log_error "File $PREUPG_GROUP does not exist. It is mandatory."
                    else
                        cat $PREUPG_GROUP
                    fi
                    ;;
                *)
                    log_error "Unknown $key for $command. Supported are 'passwd', 'group'."
                    return 1
                    ;;
            esac
            ;;
        "command")
            case $key in
                "rpm_qa")
                    _get_cached_command $PREUPG_RPM_QA
                    ;;
                "rpm_Va")
                    _get_cached_command $PREUPG_ALL_CHANGED
                    ;;
                "rpm_etc_Va")
                    _get_cached_command $PREUPG_CONFIGCHANGED
                    ;;
                "chconfig")
                    _get_cached_command $PREUPG_CHKCONFIG
                    ;;
                *)
                    log_error "Unknown $key for $command. Supported are 'rpm_qa', 'rpm_Va', 'rpm_etc_Va', 'chkconfig'".
                    return 1
                    ;;
            esac
            ;;
        "filelist")
            case $key in
                "allmyfiles")
                    _get_cached_command $PREUPG_ALLMYFILES
                    ;;
                "executable")
                    _get_cached_command $PREUPG_EXECUTABLES
                    ;;
                "rpmtrackedfiles")
                    _get_cached_command $PREUPG_RPMTRACKEDFILES
                    ;;
                "rpmrhsignedfiles")
                    _get_cached_command $PREUPG_RPM_RHSIGNED
                    ;;
                *)
                    log_error "Unknown $key for $command. Supported are 'executable', 'allmyfiles', 'rpmtrackedfiles', 'rpmrhsignedfiles'."
                    return 1
            esac
            ;;
        "info")
            ;;
        *)
            log_error "Unknown command $command. Supported are 'file', 'command', filelist', 'info'."
            return 1
            ;;
    esac

}

add_postupgrade()
{
    # Add postupgrade script to /root/preupgrade/postupgrade.d directory
    # File as first parameter has to exists in modules directory
    # Usage:    add_postupgrade file

    script_name=$1
    postupgrade_name="$PREUPG_POSTUPGRADE_DIR/`basename $script_name`"
    [ ! -f "$script_name" ] && log_error "$script_name does not exist." && exit_error
    [ -f "$postupgrade_name" ] && log_warning "$script_name already exists in $PREUPG_POSTUPGRADE_DIR"
    cp -af $script_name $postupgrade_name
}

add_manual_postupgrade()
{
    # Add postupgrade script to /root/preupgrade/noauto_postupgrade.d directory
    # File as first parameter has to exists in modules directory
    # Usage:    add_manual_postupgrade file

    script_name=$1
    postupgrade_name="$NOAUTO_POSTUPGRADE_D/`basename $script_name`"
    [ ! -f "$script_name" ] && log_error "$script_name does not exist." && exit_error
    [ -f "$postupgrade_name" ] && log_warning "$script_name already exists in $NOAUTO_POSTUPGRADE_D"
    cp -af $script_name $postupgrade_name
}

add_to_kickstart_readme()
{
    # Add filename and description to /root/preupgrade/kickstart/README file
    # Filename as first parameter which will be inserted into README file
    # Description of filename as second parameter which will be inserted into README file.
    # Format in README file is:
    # * <filename> - <description>
    # Usage:    add_to_kickstart_readme <filename> <description>
    filename=$1
    description=$2
    [ -z "$1" ] && log_error "Missing filename parameter."
    [ -z "$2" ] && log_error "Missing description of filename to kickstart README."
    echo " * $filename - $description" >> $KICKSTART_README
}

add_kickstart_dir()
{
    # Add filename /root/preupgrade/kickstart directory
    # File as first parameter has to exists in modules directory
    # Usage:    add_to_kickstart_dir <filename> <description>
    script_name=$1
    kickstart_name="$KICKSTART_DIR/`basename $script_name`"
    [ ! -f "$script_name" ] && log_error "$script_name does not exist." && exit_error
    [ -f "$kickstart_name" ] && log_warning "`basename $script_name` already exists in $KICKSTART_DIR"
    cp -af $script_name $kickstart_name
}

get_option()
{
    # Get option set up by preupgrade-assistant
    # Available options are <migration, upgrade>
    # Usage:    get_option option
    # Returns:  0,1

    option=$1
    case $option in
        "migration")
            return $MIGRATE
            ;;
        "upgrade")
            return $UPGRADE
            ;;
        *)
            log_error "Supported options are 'migration', 'upgrade'."
            ;;
    esac

}

switch_to_content()
{
    cd $CURRENT_DIRECTORY
}

check_applies_to()
{
    local RPM=1
    local RPM_NAME="$1"
    [ -z "$1" ] && RPM=0

    local NOT_APPLICABLE=0
    if [ $RPM -eq 1 ]; then
        RPM_NAME=$(echo "$RPM_NAME" | tr "," " ")
        for pkg in $RPM_NAME
        do
            is_pkg_installed "$pkg" && is_dist_native "$pkg" || {
                log_info "Package $pkg is not installed or it is not signed by Red Hat."
                NOT_APPLICABLE=1
            }
        done
    fi
    if [ $NOT_APPLICABLE -eq 1 ]; then
        exit_not_applicable
    fi
}

is_pkg_installed()
{
    grep -q "^$1[[:space:]]" $VALUE_RPM_QA || return 1
    return 0
}

check_rpm_to()
{
    local RPM=1
    local BINARY=1
    local RPM_NAME=$1
    local BINARY_NAME=$2
    local NOT_APPLICABLE=0

    [ -z "$1" ] && RPM=0
    [ -z "$2" ] && BINARY=0


    if [ $RPM -eq 1 ]; then
        RPM_NAME=$(echo "$RPM_NAME" | tr "," " ")
        for pkg in $RPM_NAME
        do
            grep "^$pkg[[:space:]]" $VALUE_RPM_QA > /dev/null
            if [ $? -ne 0 ]; then
                log_high_risk "Package $pkg is not installed."
                NOT_APPLICABLE=1
            fi
        done
    fi

    if [ $BINARY -eq 1 ]; then
        BINARY_NAME=$(echo "$BINARY_NAME" | tr "," " ")
        for bin in $BINARY_NAME
        do
            which $bin > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                log_high_risk "Binary $bin is not installed."
                NOT_APPLICABLE=1
            fi
        done
    fi


    if [ $NOT_APPLICABLE -eq 1 ]; then
        log_high_risk "Please, install all required packages (and binaries) and run preupg again to process check properly."
        exit_fail
    fi
}

# This check can be used if you need root privilegues
check_root()
{
    if [ "$(id -u)" != "0" ]; then
        log_error "This script must be run as root"
        log_slight_risk "The script must be run as root"
        exit_error
    fi
}

solution_file()
{
    echo "$1" >> $SOLUTION_FILE
}


# returns true if service in $1 is enabled in any runlevel
service_is_enabled() {
    if [ $# -ne 1 ] ; then
        echo "Usage: service_is_enabled servicename"
        return 2
    fi
    grep -qe "^${1}.*:on" "$VALUE_CHKCONFIG" && return 0
    return 1
}

# backup the config file, returns:
# true if cp succeeds,
# 1 if config file doesn't exist
# 2 if config file was not changed and thus is not necessary to back-up
backup_config_file() {
    local CONFIG_FILE=$1

    # config file exists?
    if [ ! -f "$CONFIG_FILE" ] ; then
        return 1
    fi

    # config file is changed?
    grep -qe " ${CONFIG_FILE}" ${VALUE_CONFIGCHANGED} || return 2

    mkdir -p "${VALUE_TMP_PREUPGRADE}/$(dirname "$CONFIG_FILE")"
    cp -f "${CONFIG_FILE}" "${VALUE_TMP_PREUPGRADE}${CONFIG_FILE}"
    return $?
}

space_trim() {
  echo "$@" | sed -r "s/^\s*(.*)\s*$/\1/"
}

# functions for easy parsing of config files
# returns 0 on success, otherwise 1
# requires path
conf_get_sections() {
  [ $# -eq 1 ] || return 1
  [ -f "$1" ] || return 1

  grep -E "^\[.+\]$" "$1" | sed -r "s/^\[(.+)\]$/\1/"
  return $?
}

# get all items from config file $1 inside section $2
# e.g.: conf_get_section CONFIG_FILE section-without-brackets
conf_get_section() {
  [ $# -eq 2 ] || return 1
  [ -f "$1" ] || return 1
  local _section=""

  while read line; do
    [ -z "$line" ] && continue
    echo "$line" | grep -q "^\[..*\]$" && {
      _section="$(echo "$line" | sed -E "s/^\[(.+)\]$/\1/")"
      continue # that's new section
    }
    [ -z "$_section" ] && continue

    #TODO: do not print comment lines?
    [ "$_section" == "$2" ] && echo "$line" |grep -vq "^#.*$" && echo "$line"
  done < "$1"

  return 0
}

# is_dist_native function return only 0 or 1
# return 1 if package is not installed and print warning log.
# Case DEVEL_MODE is turn off then return 0 if package is signed or 1 if not.
# Case DEVEL_MODE is turn on:
#   DIST_NATIVE = sign: return 0 if is RH_SIGNED else return 1
#   DIST_NATIVE = all: always return 0
#   DIST_NATIVE = path_to_file: return 0 if package is in file else return 1
is_dist_native()
{
    if [ $# -ne 1 ]; then
        return 1
    fi
    local pkg=$1

    grep "^$pkg[[:space:]]" $VALUE_RPM_QA > /dev/null
    if [ $? -ne 0 ]; then
        log_warning "Package $pkg is not installed on Red Hat Enterprise Linux system."
        return 1
    fi
    if [ x"$DEVEL_MODE" == "x0" ]; then
        grep "^$pkg[[:space:]]" $VALUE_RPM_RHSIGNED > /dev/null
        if [ $? -eq 0 ]; then
            return 0
        else
            return 1
        fi
    else
        case "$DIST_NATIVE" in
            "all")
                return 0
                ;;
            "sign")
                grep "^$pkg[[:space:]]" $VALUE_RPM_RHSIGNED > /dev/null
                if [ $? -eq 0 ]; then
                    return 0
                else
                    return 1
                fi
                ;;
            *)
                if [ -f "$DIST_NATIVE" ]; then
                    grep "^$pkg" $DIST_NATIVE > /dev/null
                    if [ $? -eq 0 ]; then
                        return 0
                    fi
                fi
                return 1
                ;;
        esac
    fi
}

# return list of all dist native packages according to is_dist_native()
get_dist_native_list() {
  local pkg
  while read line; do
    pkg=$(echo $line | cut -d " " -f1 )
    is_dist_native $pkg >/dev/null && echo $pkg
  done < "$VALUE_RPM_QA"
}

# here is parsed PA configuration
load_pa_configuration() {
  # this is main function for parsing
  [ -f "$PREUPGRADE_CONFIG" ] && [ -r "$PREUPGRADE_CONFIG" ] || {
    log_error "Configuration file $PREUPGRADE_CONFIG is missing or is not readable!"
    exit_error
  }
  local _pa_conf="$(conf_get_section "$PREUPGRADE_CONFIG" "preupgrade-assistant")"
  local tmp_option
  local tmp_val

  [ -z "$_pa_conf" ] && {
    log_error "Can't load any configuration from section preupgrade-assistant!"
    exit_error
  }

  for line in $_pa_conf; do
    tmp_option=$(space_trim "$(echo "$line" | cut -d "=" -f 1)")
    tmp_val=$(space_trim "$(echo "$line" | cut -d "=" -f 2-)")
    # HERE add your actions
    case $tmp_option in
      home_directory_file)
        HOME_DIRECTORY_FILE="$tmp_val"
        ;;
      user_config_file)
        USER_CONFIG_FILE=$([ "$tmp_val" == "enabled" ] && echo 1 || echo 0)
        ;;
      dist_native)
        local temp="$tmp_val"
        ;;
      *) log_error "Unknown option $tmp_option"; exit_error
    esac
  done
}

# print items from [home-dirs] which are relevant for given user
# when username is not given or config file for user is not enabled,
# items from main configuration file is printed
# returns 0 on SUCCESS, otherwise 1 and logs warning
# shouldn't be used before load_config_parser
print_home_dirs() {
  [ $# -eq 1 ] && [ $USER_CONFIG_FILE -eq 1 ] || {
    conf_get_section "$PREUPGRADE_CONFIG" "home-dirs"
    return 0
  }

  local _uconf_file="/home/$1/$HOME_DIRECTORY_FILE"
  [ -f "$_uconf_file" ] || return 0 # missing file in user's home dir is OK
  conf_get_section "$_uconf_file" "home-dirs"
}

#Function adds a package to special_pkg_list
add_pkg_to_kickstart() {
  [ $# -eq 0  ] && {
    log_debug "Missing parameters! Any package will be added." >&2
    return 1
  }

  while [ $# -ne 0 ]; do
    echo $1 >> SPECIAL_PKG_LIST
    shift
  done
  return 0
}
load_pa_configuration
switch_to_content
