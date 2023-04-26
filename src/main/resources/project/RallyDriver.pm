# -------------------------------------------------------------------------
# Package
# RallyDriver
#
# Dependencies
# common
# RallyGeneric
#
# Purpose
# Create an instance of a module depending on the procedure
#
# Copyright (c) 2014 Electric Cloud, Inc.
# All rights reserved
# -------------------------------------------------------------------------

package RallyDriver;

use strict;
use warnings;
use ElectricCommander;
use ElectricCommander::PropMod qw(/myProject/lib);
use common;
use RallyGeneric;
use JSON qw( encode_json );

# -------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------

my $DEFAULT_DEBUG = 1;
my $ERROR = 1;
my $SUCCESS = 0;

########################################################################
# new - Object constructor for Rally
#
# Arguments:
#   opts hash
#
# Returns:
#   -
#
########################################################################
sub new {
    my $class = shift;
    my $self = {
                 _cmdr => shift,
                 _opts => shift,
               };
    bless $self, $class;
    return $self;
}

########################################################################
# myCmdr - Get ElectricCommander instance
#
# Arguments:
#   none
#
# Returns:
#   ElectricCommander instance
#
########################################################################
sub myCmdr {
    my ($self) = @_;
    return $self->{_cmdr};
}

########################################################################
# opts - Get opts hash
#
# Arguments:
#   -
#
# Returns:
#   opts hash
#
########################################################################
sub opts {
    my ($self) = @_;
    return $self->{_opts};
}

########################################################################
# initialize - Set initial values
#
# Arguments:
#   -
#
# Returns:
#   -
#
########################################################################
sub initialize {
    my ($self) = @_;

    $self->{_props} = ElectricCommander::PropDB->new($self->myCmdr(), "");

    # Set defaults

    if (!defined($self->opts->{debug})) {
        $self->opts->{debug} = $DEFAULT_DEBUG;
    }
    $self->opts->{exitcode} = $SUCCESS;
    $self->opts->{JobId}    = $ENV{COMMANDER_JOBID};

    return;
}

########################################################################
# execute - run the requested operation
#
# Arguments:
#   -
#
# Returns:
#   -
#
########################################################################

sub execute {
    my $self = shift;

    $self->initialize();

    my $object;

    if ($self->opts->{module} eq "generic") {
        $object = RallyGeneric->new($self->myCmdr(), $self->opts());
    }
    else {
        die "The plugin was unable to find the @{[ $self->opts->{module} ]} Module";
    }

    my $method = $self->opts->{method};
    $object->debugMsg(0, '-----------------------------------------------------------------');
    my $response = $object->$method();

    if ($response) {
        my $jsonString = encode_json ($response);
        $self->myCmdr()->setProperty("/myJob/result_json/", $jsonString);
        $object->debugMsg(0, 'For complete JSON response, check \'result_json\' property');
    }
    return;
}

1;