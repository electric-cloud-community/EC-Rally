#
#  Copyright 2015 Electric Cloud, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

=head1 NAME

preamble.pl

=head1 DESCRIPTION

Preamble for application server plugins. Imports necessary modules.

=cut

use strict;
use utf8;
use warnings;
use ElectricCommander;
use ElectricCommander::PropDB;
use ElectricCommander::PropMod;
use Encode;
use Carp;
use JSON;
use Data::Dumper;

binmode(STDOUT, ":utf8");

$| = 1;

{
    my $ec = ElectricCommander->new();

    my $load = sub {
        my $property_path = shift;

        ElectricCommander::PropMod::loadPerlCodeFromProperty(
            $ec, $property_path
        ) or do {
            croak "Can't load property $property_path";
        };
    };

    # Loading PDK

    {
        my @locations = (
            '/myProject/pdk/',
        );
        my $display;
        my $pdk_loader = sub {
            my ($self, $target) = @_;

            $display = '[EC]@PLUGIN_KEY@-@PLUGIN_VERSION@/' . $target;
            # Undo perl'd require transformation
            # Retrieving framework part and lib part.
            my $code;
            for my $prefix (@locations) {
                my $prop = $target;
                # $prop =~ s#\.pm$##;

                $prop = "$prefix$prop";
                $code = eval {
                    $ec->getProperty("$prop")->findvalue('//value')->string_value;
                };
                last if $code;
            }
            return unless $code; # let other module paths try ;)

            # Prepend comment for correct error attribution
            $code = qq{# line 1 "$display"\n$code};

            # We must return a file in perl < 5.10, in 5.10+ just return \$code
            #    would suffice.
            open my $fd, "<", \$code
                or die "Redirect failed when loading $target from $display";

            return $fd;
        };

        push @INC, $pdk_loader;
    }
};
# create PDK object


sub get_pdk {
    require FlowPDF;
    import FlowPDF;
    require FlowPDF::Context;
    import FlowPDF::Context;
    require FlowPDF::ContextFactory;
    import FlowPDF::ContextFactory;
    my $ec = ElectricCommander->new();

    my $procedureName = $ec->getProperty('/myProcedure/procedureName')->findvalue('//value')->string_value();
    my $stepName = $ec->getProperty('/myJobStep/stepName')->findvalue('//value')->string_value();
    my $pluginName = '@PLUGIN_KEY@';
    my $pluginVersion = '@PLUGIN_VERSION@';

    *FlowPDF::pluginInfo = sub {
        return {
            pluginName          => '@PLUGIN_KEY@',
            pluginVersion       => '@PLUGIN_VERSION@',
            config_fields       => [ 'config_name', 'configuration_name', 'config', 'connection_config' ],
            config_locations    => [ 'Rally_cfgs', 'ec_plugin_cfgs' ],
            defaultConfigValues => {
            }
        }
    };
    my $flowpdf = FlowPDF->new({
        pluginName      => '@PLUGIN_KEY@',
        pluginVersion   => '@PLUGIN_VERSION@',
        configFields    => [ 'config_name', 'configuration_name', 'config', 'connection_config' ],
        configLocations => [ 'Rally_cfgs', 'ec_plugin_cfgs' ],
        defaultConfigValues => {
        },
        contextFactory  => FlowPDF::ContextFactory->new({
            procedureName => $procedureName,
            stepName      => $stepName
        })
    });
    return $flowpdf;
}

