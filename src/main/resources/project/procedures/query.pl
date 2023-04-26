##########################
# queryObject.pl
##########################
use warnings;
use strict;
use Encode;
use utf8;
use open IO => ':encoding(utf8)';

$[/myProject/procedure_helpers/pdk_loader]

## Create ElectricCommander instance
my $ec = new ElectricCommander();
$ec->abortOnError(0);

my $opts;

$opts->{connection_config}      = ($ec->getProperty("connection_config"))->findvalue('//value')->string_value;
$opts->{rally_object_type}      = ($ec->getProperty("rally_object_type"))->findvalue('//value')->string_value;
$opts->{rally_queryString}      = ($ec->getProperty("rally_queryString"))->findvalue('//value')->string_value;
$opts->{rally_orderString}      = ($ec->getProperty("rally_orderString"))->findvalue('//value')->string_value;
$opts->{rally_pageSize}         = ($ec->getProperty("rally_pageSize"))->findvalue('//value')->string_value;
$opts->{rally_startIndex}       = ($ec->getProperty("rally_startIndex"))->findvalue('//value')->string_value;
$opts->{rally_fullObject}       = ($ec->getProperty("rally_fullObject"))->findvalue('//value')->string_value;
$opts->{rally_workspace}        = ($ec->getProperty("rally_workspace"))->findvalue('//value')->string_value;
$opts->{rally_project}          = ($ec->getProperty("rally_project"))->findvalue('//value')->string_value;
$opts->{rally_projectScopeUp}   = ($ec->getProperty("rally_projectScopeUp"))->findvalue('//value')->string_value;
$opts->{rally_projectScopeDown} = ($ec->getProperty("rally_projectScopeDown"))->findvalue('//value')->string_value;

$[/myProject/procedure_helpers/preamble]

$opts->{method} = 'query';
$opts->{module} = 'generic';

$rally->execute();
exit($opts->{exitcode});
