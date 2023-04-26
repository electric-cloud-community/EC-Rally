##########################
# deleteObject.pl
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

$opts->{connection_config} = ($ec->getProperty("connection_config"))->findvalue('//value')->string_value;
$opts->{rally_object_type} = ($ec->getProperty("rally_object_type"))->findvalue('//value')->string_value;
$opts->{use_formattedId}   = ($ec->getProperty("use_formattedId"))->findvalue('//value')->string_value;
$opts->{rally_ID}          = ($ec->getProperty("rally_ID"))->findvalue('//value')->string_value;

$[/myProject/procedure_helpers/preamble]

$opts->{method} = 'delete';
$opts->{module} = 'generic';

$rally->execute();
exit($opts->{exitcode});
