# WARNING
# Do not edit this file manually. Your changes will be overwritten with next FlowPDF update.
# WARNING

=head1 NAME

FlowPDF::StepParameters

=head1 AUTHOR

CloudBees

=head1 DESCRIPTION

This class represents current step parameters, that are defined for current procedure step or current pipeline task.

=head1 SYNOPSIS

To get a FlowPDF::StepParameters object you need to use getStepParameters() method from L<FlowPDF::Context>.

=head1 METHODS

=cut

package FlowPDF::StepParameters;
use base qw/FlowPDF::BaseClass2/;
use FlowPDF::Types;

__PACKAGE__->defineClass({
    parametersList => FlowPDF::Types::ArrayrefOf(FlowPDF::Types::Scalar()),
    parameters => FlowPDF::Types::Reference('HASH'),
});

use strict;
use warnings;
use Carp;

use FlowPDF::Helpers qw/bailOut/;

# sub isParameterExists {};
# sub getParameter {};
# sub setParameter {};
# sub setCredential {};
# sub getCredential {};


=head2 isParameterExists()

=head3 Description

Returns true if parameter exists in the current step.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (Boolean) True if parameter exists.

=back

=head3 Usage

%%%LANG=perl%%%

    if ($stepParameters->isParameterExists('query')) {
        ...;
    }

%%%LANG%%%

=cut

sub isParameterExists {
    my ($self, $parameterName) = @_;

    my $p = $self->getParameters();
    if (exists $p->{$parameterName}) {
        return 1;
    }
    return 0;
}

=head2 getParameter($parameterName)

=head3 Description

Returns an L<FlowPDF::Parameter> object or L<FlowPDF::Credential> object.

=head3 Parameters

=over 4

=item (String) Name of parameter to get.

=back

=head3 Returns

=over 4

=item (L<FlowPDF::Parameter>|L<FlowPDF::Credential>) Parameter or credential by it's name

=back

=head3 Usage

To get parameter object:

%%%LANG=perl%%%

    my $query = $stepParameters->getParameter('query');

%%%LANG%%%

If your parameter is an L<FlowPDF::Parameter> object, you can get its value either by getValue() method, or using string context:

%%%LANG=perl%%%

    print "Query:", $query->getValue();

%%%LANG%%%

Or:

%%%LANG=perl%%%

    print "Query: $query"

%%%LANG%%%

If your parameter is L<FlowPDF::Credential>, follow its own documentation.

=cut



sub getParameter {
    my ($self, $parameterName) = @_;

    if (!defined $parameterName) {
        bailOut("Parameter name is mandatory parameter");
    }
    if (!$self->isParameterExists($parameterName)) {
        return undef;
    }

    return $self->getParameters()->{$parameterName};
}


=head2 getRequiredParameter($parameterName)

=head3 Description

Returns an L<FlowPDF::Parameter> object or L<FlowPDF::Credential> object if this parameter exists.

If parameter does not exist, this method aborts execution with exit code 1.

This exception can't be catched.

=head3 Parameters

=over 4

=item (String) Name of parameter to get.

=back

=head3 Returns

=over 4

=item (L<FlowPDF::Parameter>|L<FlowPDF::Credential>) Parameter or credential by it's name

=back

=head3 Usage

To get parameter object:

%%%LANG=perl%%%

    my $query = $stepParameters->getRequiredParameter('query');

%%%LANG%%%

If your parameter is an L<FlowPDF::Parameter> object, you can get its value either by getValue() method, or using string context:

%%%LANG=perl%%%

    print "Query:", $query->getValue();

%%%LANG%%%

Or:

%%%LANG=perl%%%

    print "Query: $query"

%%%LANG%%%

If your parameter is L<FlowPDF::Credential>, follow its own documentation.

=cut

# TODO: Switch from BailOut to exception here.
sub getRequiredParameter {
    my ($self, $parameterName) = @_;

    my $value = $self->getParameter($parameterName);
    if (!defined $value) {
        bailOut("Required parameter $parameterName does not exist");
    }

    return $value;
}


=head2 asHashref()

=head3 Description

This function returns a HASH reference that is made from FlowPDF::StepParameters object.
Where key is a name of parameter and value is a value of parameter.

For credentials the same pattern as for getRuntimeParameters from L<FlowPDF::Context> is being followed.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (HASH reference) A HASH reference to a HASH with step parameters.

=back

=head3 Exceptions

=over 4 

=item None

=back

=head3 Usage

%%%LANG=perl%%%

    my $stepParameters = $context->getStepParameters()->asHashref();
    logInfo("Application path is: $stepParameters->{applicationPath}");

%%%LANG%%%

=cut

sub asHashref {
    my ($self) = @_;

    my $retval = {};
    my $parametersList = $self->getParametersList();
    for my $key (@$parametersList) {
        my $row = $self->getParameter($key);

        next unless defined $row;
        if (ref $row eq 'FlowPDF::Credential') {
            my $prefix = '';

            if ($key =~ m/^(.*?_)credential/) {
                $prefix = $1;
            }

            my $userName = $row->getUserName();
            my $password = $row->getSecretValue();

            if ($userName) {
                $retval->{$prefix . 'user'} = $userName;
            }
            if ($password) {
                $retval->{$prefix . 'password'} = $password;
            }
        }
        else {
            $retval->{$key} = $row->getValue();
        }
    }

    return $retval;
}


1;
