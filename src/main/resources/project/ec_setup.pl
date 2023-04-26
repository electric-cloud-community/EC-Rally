#
#  Copyright 2019 CloudBees, Inc.
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

# External Credential Manageent Update:
# We're retrieving the steps with attached creds from property sheet

use strict;
use warnings;
no warnings 'redefine';
use Data::Dumper;

use ElectricCommander;
use JSON qw(decode_json);
use subs qw(debug);
use Time::HiRes qw(time gettimeofday tv_interval);

my @logs = ();
sub debug($) {
    my ($message) = @_;
    push @logs, scalar time . ": " . $message;

    if ($ENV{EC_SETUP_DEBUG}) {
        print scalar time . ": $message\n";
    }
}

my $stepsWithCredentials = getStepsWithCredentials();
# warn Dumper $stepsWithCredentials;
# End of External Credential Management Update

my %create = (
    label       => "Rally - Create Object",
    procedure   => "CreateObject",
    description => "Create a new Object on Rally server.",
    category    => "Application Lifecycle Management"
);
my %read = (
    label       => "Rally - Read Object",
    procedure   => "ReadObject",
    description => "Read an Object on Rally server, and return the json.",
    category    => "Application Lifecycle Management"
);
my %update = (
    label       => "Rally - Update Object",
    procedure   => "UpdateObject",
    description => "Update an existing Object on Rally server.",
    category    => "Application Lifecycle Management"
);
my %delete = (
    label       => "Rally - Delete Object",
    procedure   => "DeleteObject",
    description => "Delete a Rally configuration.",
    category    => "Application Lifecycle Management"
);
my %query = (
    label       => "Rally - Query Object",
    procedure   => "QueryObject",
    description => "Query for objects on Rally server.",
    category    => "Application Lifecycle Management"
);






$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Rally - CreateObject");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Rally - ReadObject");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Rally - UpdateObject");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Rally - DeleteObject");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/EC-Rally - QueryObject");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Rally - Create Object");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Rally - Read Object");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Rally - Update Object");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Rally - Delete Object");
$batch->deleteProperty("/server/ec_customEditors/pickerStep/Rally - Query Object");
               
@::createStepPickerSteps = (\%create, \%read, \%update, \%delete, \%query);
my @formalOutputParameters = ();


if ($upgradeAction eq 'upgrade') {
    migrateConfigurations($otherPluginName);
    migrateProperties($otherPluginName);
    debug "Migrated properties";
    reattachExternalCredentials($otherPluginName);
}

# Disabling this branch of logic temporary
if (0 && $upgradeAction eq 'upgrade') {
    my $query = $commander->newBatch();
    my $newcfg = $query->getProperty(
        "/plugins/$pluginName/project/Rally_cfgs");
    my $oldcfgs = $query->getProperty(
        "/plugins/$otherPluginName/project/Rally_cfgs");
    my $creds = $query->getCredentials(
        "\$[/plugins/$otherPluginName]");

    local $self->{abortOnError} = 0;
    $query->submit();

    # if new plugin does not already have cfgs
    if ($query->findvalue($newcfg, "code") eq "NoSuchProperty") {
        # if old cfg has some cfgs to copy
        if ($query->findvalue($oldcfgs,"code") ne "NoSuchProperty") {
            $batch->clone({
                path      => "/plugins/$otherPluginName/project/Rally_cfgs",
                cloneName => "/plugins/$pluginName/project/Rally_cfgs"
            });
        }
    }

    # Copy configuration credentials and attach them to the appropriate steps
    my $nodes = $query->find($creds);
    if ($nodes) {
        my @nodes = $nodes->findnodes('credential/credentialName');
        for (@nodes) {
            my $cred = $_->string_value;

            # Clone the credential
            $batch->clone({
                path => "/plugins/$otherPluginName/project/credentials/$cred",
                cloneName => "/plugins/$pluginName/project/credentials/$cred"
            });

            # Make sure the credential has an ACL entry for the new project principal
            my $xpath = $commander->getAclEntry("user", "project: $pluginName", {
                projectName => $otherPluginName,
                credentialName => $cred
            });
            if ($xpath->findvalue("//code") eq "NoSuchAclEntry") {
                $batch->deleteAclEntry("user", "project: $otherPluginName", {
                    projectName => $pluginName,
                    credentialName => $cred
                });
                $batch->createAclEntry("user", "project: $pluginName", {
                    projectName => $pluginName,
                    credentialName => $cred,
                    readPrivilege => 'allow',
                    modifyPrivilege => 'allow',
                    executePrivilege => 'allow',
                    changePermissionsPrivilege => 'allow'
                });
            }
            for my $step (@$stepsWithCredentials) {
            # Attach the credential to the appropriate steps
                $batch->attachCredential("\$[/plugins/$pluginName/project]", $cred, {
                    procedureName => $step->{procedureName},
                    stepName => $step->{stepName}
                });
            }
        }
    }
    reattachExternalCredentials($otherPluginName);
}


if ($promoteAction eq 'promote') {
    reattachExternalConfigurations($otherPluginName);
    ## Check if agent supports formalOutputParameters API,
    if (exists $ElectricCommander::Arguments{getFormalOutputParameters}) {
        my $versions = $commander->getVersions();

        if (my $version = $versions->findvalue('//version')) {
            require ElectricCommander::Util;
            ElectricCommander::Util->import('compareMinor');

            if (compareMinor($version, '8.3') >= 0) {
                checkAndSetOutputParameters(\@formalOutputParameters);
            }
        }
    }
}

sub checkAndSetOutputParameters {
    my ($parameters) = @_;

    # Form flatten unique list of procedureNames
    # and get all parameters for defined procedures
    my $query = $commander->newBatch();
    my %subs = ();
    foreach my $param (@$parameters) {
        my $proc_name = $param->{procedureName};
        $subs{$proc_name} = 1;
    }
    ;

    foreach (keys %subs) {
        $subs{$_} = $query->getFormalOutputParameters($otherPluginName, {
            procedureName => $_
        });
    }
    $query->submit();

    my @params_to_create = ();
    foreach my $proc_name (keys %subs) {
        my $response_for_params = $query->find($proc_name);

        push @params_to_create, checkMissingOutputParameters( $parameters, $response_for_params );
    }

    createMissingOutputParameters(@params_to_create);
}

sub checkMissingOutputParameters {
    my ($parameters, $response) = @_;
    my @parameters = @{$parameters};

    # This is list of keys to build unique parameter's indices
    my @key_parts = ('formalOutputParameterName', 'procedureName');
    my @params_to_create = ();

    my %parsed_parameters = ();
    if ($response) {
        my @defined_params = ($response->findnodes('formalOutputParameter'));

        if (@defined_params) {
            for my $param (@defined_params) {
                my $key = join('_', map {
                    $param->find($_)->string_value()
                } @key_parts
                           );

                # Setting a flag parameter that parameter is already created
                $parsed_parameters{$key} = 1;
            }
        }
    }

    foreach my $param (@parameters) {
        my $key = join('_', map {$param->{$_} || ''} @key_parts);

        if (!exists $parsed_parameters{$key}) {
            push(@params_to_create, [
                $pluginName,
                $param->{formalOutputParameterName},
                {
                    procedureName => $param->{procedureName}
                }
            ]);
        }
    }

    return @params_to_create;
}

sub createMissingOutputParameters {
    my (@params_to_create) = @_;

    my @responses = ();
    if (@params_to_create) {
        my $create_batch = $commander->newBatch();
        push @responses, $create_batch->createFormalOutputParameter(@$_) foreach (@params_to_create);
        $create_batch->submit();
    }
    # print Dumper \@responses
    return 1;
}

sub get_major_minor {
    my ($version) = @_;

    if ($version =~ m/^(\d+\.\d+)/) {
        return $1;
    }
    return undef;
}


sub reattachExternalCredentials {
    my ($otherPluginName) = @_;

    my $configName = getConfigLocation($otherPluginName);
    my $configsPath = "/plugins/$otherPluginName/project/$configName";

    my $xp = $commander->getProperty($configsPath);

    my $id = $xp->findvalue('//propertySheetId')->string_value();
    my $props = $commander->getProperties({propertySheetId => $id});
    for my $node ($props->findnodes('//property/propertySheetId')) {
        my $configPropertySheetId = $node->string_value();
        my $config = $commander->getProperties({propertySheetId => $configPropertySheetId});

        # iterate through props to get credentials.
        for my $configRow ($config->findnodes('//property')) {
            my $propName = $configRow->findvalue('propertyName')->string_value();
            my $propValue = $configRow->findvalue('value')->string_value();
            # print "Name $propName, value: $propValue\n";
            if ($propName =~ m/credential$/s && $propValue =~ m|^\/|s) {
                for my $step (@$stepsWithCredentials) {
                    $batch->attachCredential({
                        projectName    => $pluginName,
                        procedureName  => $step->{procedureName},
                        stepName       => $step->{stepName},
                        credentialName => $propValue,
                    });
                    #    debug "Attached credential to $step->{stepName}";
                }
                print "Reattaching $propName with val: $propValue\n";
            }
        }
        # exit 0;
    }
}

sub getConfigLocation {
    my ($otherPluginName) = @_;

    my $configName = eval {
        $commander->getProperty("/plugins/$otherPluginName/project/ec_configPropertySheet")->findvalue('//value')->string_value
    } || 'Rally_cfgs';
    return $configName;
}

sub getStepsWithCredentials {
    my $retval = [];
    eval {
        my $pluginName = '@PLUGIN_NAME@';
        my $stepsJson = $commander->getProperty("/projects/$pluginName/procedures/CreateConfiguration/ec_stepsWithAttachedCredentials")->findvalue('//value')->string_value;
        $retval = decode_json($stepsJson);
    };
    return $retval;
}

sub reattachExternalConfigurations {
    my ($otherPluginName) = @_;

    my %migrated = ();
    # For the configurations that exists while the plugin was deleted
    # The api is new so it requires the upgraded version of the agent
    eval {
        my $cfgs = $commander->getPluginConfigurations({
            pluginKey => '@PLUGIN_KEY@',
        });
        my @creds = ();
        for my $cfg ($cfgs->findnodes('//pluginConfiguration/credentialMappings/parameterDetail')) {
            my $value = $cfg->findvalue('parameterValue')->string_value();
            push @creds, $value;
        }

        for my $cred (@creds) {
            next if $migrated{$cred};
            for my $stepWithCreds (@$stepsWithCredentials) {
                $commander->attachCredential({
                    projectName => "/plugins/$pluginName/project",
                    credentialName => $cred,
                    procedureName => $stepWithCreds->{procedureName},
                    stepName => $stepWithCreds->{stepName}
                });
            }
            $migrated{$cred} = 1;
            debug "Migrated $cred";
        }
        1;
    } or do {
        debug "getPluginConfiguration API is not supported on the promoting agent, falling back";
        for my $stepWithCreds (@$stepsWithCredentials) {
            my $step = $commander->getStep({
                projectName => "/plugins/$otherPluginName/project",
                procedureName => $stepWithCreds->{procedureName},
                stepName => $stepWithCreds->{stepName},
            });
            for my $attachedCred ($step->findnodes('//attachedCredentials/credentialName')) {
                my $credName = $attachedCred->string_value();
                $commander->attachCredential({
                    projectName => "/plugins/$pluginName/project",
                    credentialName => $credName,
                    procedureName => $stepWithCreds->{procedureName},
                    stepName => $stepWithCreds->{stepName}
                });
                $migrated{$credName} = 1;
                debug "Migrated credential $credName to $stepWithCreds->{procedureName}";
            }
        }
    };
}

sub migrateConfigurations {
    my ($otherPluginName) = @_;

    my $configName = getConfigLocation($otherPluginName);
    # my $configName = eval {
    #     $commander->getProperty("/plugins/$otherPluginName/project/ec_configPropertySheet")->findvalue('//value')->string_value
    # } || 'ec_plugin_cfgs';

    $commander->clone({
        path      => "/plugins/$otherPluginName/project/$configName",
        cloneName => "/plugins/$pluginName/project/$configName"
    });

    my $xpath = $commander->getCredentials("/plugins/$otherPluginName/project");
    for my $credential ($xpath->findnodes('//credential')) {
        my $credName = $credential->findvalue('credentialName')->string_value;

        # If credential name starts with "/", it means that it is a reference.
        # We do not need to clone it.
        # if ($credName !~ m|^\/|s) {
        debug "Migrating old configuration $credName";
        $batch->clone({
            path      => "/plugins/$otherPluginName/project/credentials/$credName",
            cloneName => "/plugins/$pluginName/project/credentials/$credName"
        });
        $batch->deleteAclEntry({
            principalName  => "project: $otherPluginName",
            projectName    => $pluginName,
            credentialName => $credName,
            principalType  => 'user'
        });
        $batch->deleteAclEntry({
            principalType  => 'user',
            principalName  => "project: $pluginName",
            credentialName => $credName,
            projectName    => $pluginName,
        });

        $batch->createAclEntry({
            principalType              => 'user',
            principalName              => "project: $pluginName",
            projectName                => $pluginName,
            credentialName             => $credName,
            objectType                 => 'credential',
            readPrivilege              => 'allow',
            modifyPrivilege            => 'allow',
            executePrivilege           => 'allow',
            changePermissionsPrivilege => 'allow'
        });
        #}

        for my $step (@$stepsWithCredentials) {
            $batch->attachCredential({
                projectName    => $pluginName,
                procedureName  => $step->{procedureName},
                stepName       => $step->{stepName},
                credentialName => $credName,
            });
            debug "Attached credential to $step->{stepName}";
        }
    }
}

sub migrateProperties {
    my ($otherPluginName) = @_;
    my $clonedPropertySheets = eval {
        decode_json($commander->getProperty("/plugins/$otherPluginName/project/ec_clonedProperties")->findvalue('//value')->string_value);
    };
    unless ($clonedPropertySheets) {
        debug "No properties to migrate";
        return;
    }

    for my $prop (@$clonedPropertySheets) {
        $commander->clone({
            path      => "/plugins/$otherPluginName/project/$prop",
            cloneName => "/plugins/$pluginName/project/$prop"
        });
        debug "Cloned $prop"
    }
}
