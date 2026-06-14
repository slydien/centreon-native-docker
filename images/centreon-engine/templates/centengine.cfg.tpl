# ============================================================================
# centengine.cfg — minimal bootstrap config for the container
# Overwritten as soon as a Gorgone export arrives.
# All values honour the image paths (shared volumes).
# ============================================================================

cfg_file=${CENTREON_ENGINE_CFGDIR}/hosts.cfg
cfg_file=${CENTREON_ENGINE_CFGDIR}/services.cfg
cfg_file=${CENTREON_ENGINE_CFGDIR}/contacts.cfg
cfg_file=${CENTREON_ENGINE_CFGDIR}/commands.cfg
cfg_file=${CENTREON_ENGINE_CFGDIR}/timeperiods.cfg
resource_file=${CENTREON_ENGINE_CFGDIR}/resource.cfg

log_file=${CENTREON_ENGINE_LOGDIR}/centengine.log
log_archive_path=${CENTREON_ENGINE_LOGDIR}/archives/

status_file=${CENTREON_ENGINE_VARDIR}/status.dat
state_retention_file=${CENTREON_ENGINE_VARDIR}/retention.dat
command_file=${CENTREON_ENGINE_VARDIR}/rw/centengine.cmd

# cbmod : broker module that forwards events to centreon-broker-sql
broker_module=/usr/lib64/nagios/cbmod.so /etc/centreon-broker/central-module.json
broker_module_directory=/usr/lib64/centreon-engine

interval_length=60
service_inter_check_delay_method=s
host_inter_check_delay_method=s
max_concurrent_checks=400
max_service_check_spread=5
max_host_check_spread=5
service_check_timeout=10
host_check_timeout=12
check_result_reaper_frequency=5
max_check_result_reaper_time=30
sleep_time=0.2
enable_predictive_host_dependency_checks=1
enable_predictive_service_dependency_checks=1
soft_state_dependencies=0
log_rotation_method=d
use_syslog=0
log_notifications=1
log_service_retries=1
log_host_retries=1
log_event_handlers=1
log_initial_states=0
log_external_commands=1
log_passive_checks=1
retain_state_information=1
retention_update_interval=60
use_retained_program_state=1
use_retained_scheduling_info=1
service_freshness_check_interval=60
host_freshness_check_interval=60
check_for_orphaned_services=0
check_for_orphaned_hosts=0
check_service_freshness=1
check_host_freshness=0
date_format=euro
illegal_object_name_chars=~!$%^&*"|'<>?,()=
illegal_macro_output_chars=`~$^&"|'<>
admin_email=admin@localhost
admin_pager=admin@localhost
event_broker_options=-1
