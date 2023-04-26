use ElectricCommander;
use File::Basename;
use ElectricCommander::PropDB;
use ElectricCommander::PropMod;
use Encode;
use utf8;

$| = 1;

use constant {
               SUCCESS => 0,
               ERROR   => 1,
             };

my $pluginKey  = 'EC-Rally';
my $xpath      = $ec->getPlugin($pluginKey);
my $pluginName = $xpath->findvalue('//pluginVersion')->value;
print "Using plugin $pluginKey version $pluginName\n";
$opts->{pluginVer} = $pluginName;

my $pdk = get_pdk();
my $cfg = $pdk->getContext()->getConfigValuesAsHashref();


if ($cfg) {
    for my $k (keys %$cfg) {
        $opts->{$k} = $cfg->{$k};
    }
    $opts->{rally_user} = delete $opts->{user};
    $opts->{rally_pass} = delete $opts->{password};
}

$opts->{JobStepId} = "$[/myJobStep/jobStepId]";


## Load the actual code into this process
if (!ElectricCommander::PropMod::loadPerlCodeFromProperty($ec, '/myProject/driver/RallyDriver')) {
    print 'Could not load RallyDriver.pm\n';
    exit ERROR;
}

## Make an instance of the object, passing in options as a hash
my $rally = new RallyDriver($ec, $opts);
