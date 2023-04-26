# WARNING
# Do not edit this file manually. Your changes will be overwritten with next FlowPDF update.
# WARNING

=head1 NAME

FlowPDF::Client::ModernREST

=head1 AUTHOR

CloudBees

=head1 DESCRIPTION

This module provides more advanced rest client for various HTTP interactions.

Unlile FlowPDF::Client::REST this client provides much more flexibility and uses slightly different approach.

The main feature of FlowPDF::Client::ModernREST is request mapping.

Request mapping provides a possibility of remapping the request object before acually running the request.

This is useful when you need to provide an integration with gateway-like software, like MuleSoft.

You can get FlowPDF::Client::ModernREST object using regular constructor: new(), or through L<FlowPDF::Context> object, using newRESTClient({modern => 1}) methods.

Retrieving FlowPDF::Client::ModernREST object from L<FlowPDF::Context> is preferred, because during retrieval from context, some components may be applied automatically to FlowPDF::Client::REST object, like proxy, L<FlowPDF::Log>, endpoint, authorisation and many more.

=head1 METHODS

=cut


package FlowPDF::Client::ModernREST;
use base qw/FlowPDF::BaseClass2/;
use strict;
use warnings;
use Carp;

use FlowPDF::Types;
use Data::Dumper;
use LWP::UserAgent;
use FlowPDF::Client::REST::Auth;
use FlowPDF::Client::ModernREST::HTTPRequest;
use FlowPDF::Helpers qw/isModernPerl isLegacyPerl/;
#
__PACKAGE__->defineClass({
    # mandatory base url for all interactions
    baseUrl => FlowPDF::Types::Scalar(),
    # optional proxy component that is being used for all ua/request modifications.
    proxyComponent => FlowPDF::Types::Reference('FlowPDF::Component::Proxy'),
    # optional set of default headers, subroutine references are also supported.
    defaultHeaders => FlowPDF::Types::Reference('HASH'),
    # optional request mappings
    mappings => FlowPDF::Types::Reference('HASH'),
    # a user agent that is being set by rest client during creation.
    userAgent => FlowPDF::Types::Reference('LWP::UserAgent'),
    globalMappingVariables => FlowPDF::Types::Reference('HASH'),
    # ignore ssl errors or not. Default is to not ignore ssl errors
    ignoreSSLErrors => FlowPDF::Types::Enum(0, 1),
    # auth values
    auth            => FlowPDF::Types::Reference('FlowPDF::Client::REST::Auth')
});


=head2 new($parameters)

=head3 Description

Constructor. Creates new FlowPDF::Client::REST object.

=head3 Parameters

Constructor accepts a HASH reference with the parameters as keys.

%%%LANG=perl%%%
    my $rest = FlowPDF::Client::ModernREST->new($params);
%%%LANG%%%

Keys of $params HASH reference are:


=over 4

=item (Required)(String) baseUrl

A string, base URL for requests.
For example, it could be set to 'http://localhost:8888', and then you could add URNs like /api or / using parameters in newRequest method.

=item (Optional)(HASH ref) mappings

A hash reference with the following fields: method, endpoint, headers and content. Example:

%%%LANG=perl%%%

    my $mappings = {
        headers => {
            'accept' => 'application/json',
            'origin-method' => '$METHOD',
            '*' => '$HEADERS'
        },
        content => 'content: $CONTENT',
        method => 'POST',
        endpoint => '$URL/$URN/test-mappings'

    };

%%%LANG%%%

Default mappings are:

%%%LANG=perl%%%

    my $mappings = {
        headers => '$HEADERS',
        content => '$CONTENT',
        method  => '$METHOD',
        endpoint => '$URL/$URN' # or $ENDPOINT
    };

%%%LANG%%%

In general mappings allow you to remap the request on the configuration phase of a plugin in pure declarative manner. So that REST client will take care of those mappings during request object creation.

=item (Optional)(FlowPDF::Client::REST::Auth) auth

See details in L<FlowPDF::Client::REST::Auth> documentation.

=item (Optional)(LWP::UserAgent ref)userAgent

A customized and pre-set LWP::UserAgent object.
If it is not provided, FlowPDF::Client::ModernREST will create its own LWP::UserAgent object with all required manipulations.

=item (Optional)(HASH ref) defaultHeaders

A hash reference of headers that will be applied to the HTTP::Request object.
Useful if you need to create some headers in the code when it is not possible to provide them using config.
Supports scalars and code refs:

%%%LANG=perl%%%
    my $default_headers = {
        one => 'two',
        three => 'four',
        five => sub {
            return 'six ' . $time
        }
    };

%%%LANG%%%

Also note that CODE references are being executed on time of request object creation.

=item (Optional)(Enum: 1, 0) ignoreSSLErrors

=back

=head3 Returns

=over 4

=item L<FlowPDF::Client::ModernREST> object.

=back

=cut

sub new {
    my ($class, $params) = @_;

    my $baseUrl = $params->{baseUrl};
    if (!$baseUrl) {
        croak "baseUrl is mandatory parameter";
    }

    if ($params->{mappings}) {
        my $m = $params->{mappings};
        if (
            !defined $m->{content}  ||
            !defined $m->{headers}  ||
            !defined $m->{endpoint} ||
            !defined $m->{method}
        ) {
            # TODO: Improve this exception
            croak "Mappings should have those 4 keys: content, endpoint, headers, method";
        }
    }
    # Handling auth
    my $restAuth = FlowPDF::Client::REST::Auth->new({
        authValues => {},
        authType   => '',
    });

    # TODO: Implement auth parameter validation
    # TODO: Handle creation params
    my $restAuthValues = $restAuth->getAuthValues();
    my $oauth = undef;
    if ($params->{auth} && $params->{auth}->{type}) {
        my $auth = $params->{auth};

        if ($auth->{type} eq 'oauth') {
            $restAuth->setAuthType('oauth');
            delete $auth->{type};
            # op stands for ouathParams
            my $op = $auth;

            if ($op->{oauth_version} ne '1.0') {
                croak "Currently OAuth version $op->{oauth_version} is not supported. Suported versions: 1.0";
            }

            # request_method is removed from mandatory fields list for now.
            for my $p (qw/oauth_signature_method oauth_version/) {
                if (!defined $op->{$p}) {
                    croak "$p is mandatory for oauth component";
                }
            }
            fwLogDebug("Loading FlowPDF::Component::OAuth");
            $oauth = FlowPDF::ComponentManager->loadComponent('FlowPDF::Component::OAuth', $auth);
            fwLogDebug("OAuth component has been loaded.");
            $restAuthValues->{oauthComponent} = $oauth;
        }
        elsif ($auth->{type} eq 'basic') {
            $restAuth->setAuthType('basic');
            # TODO: Remove later one of these options and keep only one.
            if ($auth->{userName} || $auth->{username}) {
                $restAuthValues->{username} = $auth->{userName} || $auth->{username};
            }

            if ($auth->{password}) {
                $restAuthValues->{password} = $auth->{password};
            }
        }
        elsif ($auth->{type} eq 'bearer') {
            logWarning("Bearer auth type is not implemented yet");
        }
        else {
            if (keys %$auth) {
                logWarning("Following auth keys are not supported: " . join(", ", keys(%$auth)));
            }
        }

        # TODO: fix this later, go through creationParameters
        # print "REF AUTH:", Dumper $restAuth;
        $params->{auth} = $restAuth;
    }

    my $self = $class->SUPER::new($params);
    # TODO: handle other params
    my $ua;
    if ($params->{userAgent}) {
        $ua = $params->{userAgent};
    }
    else {
        $ua = LWP::UserAgent->new();
    }

    my $ignoreSSLErrors = $self->getIgnoreSSLErrors();
    if (defined $ignoreSSLErrors && $ignoreSSLErrors == 1) {
        if (isModernPerl()) {
            $ua->ssl_opts(verify_hostname => 0);
        }
        else {
            $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
        }
    }

    if (my $proxy = $self->getProxyComponent()) {
        # 1. Apply proxy
        $proxy->apply();
        $ua = $proxy->augment_lwp($ua);
    }
    $self->setUserAgent($ua);
    return $self;
}
# Creates new request, accepts data in format that is compatible with HTTP::Request->new()
# to be as a drop-in replacement for HTTP::Request to keep compatibility with FlowPDF::Client::REST
# parameters are: $method, $uri, $header, $content

# if the urn is set to absolute url then plain HTTP::Request object is created.

=head2 newRequest($method, $urn, $headers, $content)

=head3 Description

Creates a new L<FlowPDF::Client::ModernREST::HTTPRequest> object.

=head3 Parameters

=over 4

=item $method

HTTP request method: GET, POST, PUT, HEAD, etc.

=back

=over 4

=item $urn

A URN of resource. ModernREST will use baseUrl parameter to create absolute URI.

For example could be set to '/api'.

=back

=over 4

=item $headers

A hashref (or arrayref) of headers.

=back

=over 4

=item $content

A content for request types where it is supported (HEAD and GET don't support content for example).

=back

=head3 Returns

L<FlowPDF::Client::ModernREST::HTTPRequest>

=cut

sub newRequest {
    my ($self, $method, $urn, $headers, $content) = @_;

    # it returns [] if there are no default headers
    my $requestHeaders = $self->compileDefaultHeaders();
    if ($headers && ref $headers eq 'ARRAY') {
        # TODO: add support of code references in supplied headers.
        @$requestHeaders = (@$requestHeaders, @$headers);
    }
    elsif ($headers && ref $headers eq 'HASH') {
        if (ref $headers eq 'HASH') {
            my $t = [];
            for my $k (keys %$headers) {
                push @$t, $k, $headers->{$k};
            }
            @$requestHeaders = (@$requestHeaders, @$t);
        }
        else {
            croak "only hashes and arrays are supported";
        }
    }
    # TODO: handle compatible call when $urn is an absolute URL
    my $req = FlowPDF::Client::ModernREST::HTTPRequest->new({
        baseUrl => $self->getBaseUrl(),
        method => $method,
        urn => $urn,
        headers => $requestHeaders,
        content => $content,
    });
    if (my $proxy = $self->getProxyComponent()) {
        $req->setProxyComponent($proxy);
    }
    # if ($self->defaultHeaders()) {
    #     ...;
    # }
    if ($self->getMappings()) {
        my $mappings = $self->getMappings();
        my %mappings = %$mappings;
        $mappings = \%mappings;
        $mappings = $self->compileRequestMappings($req);
        $req->setMappings($mappings);
    }
    # TODO: Handle headers to be set, not to forget about sub headers.
    return $req;
}


=head2 doRequest($request)

=head3 Description

Performs request and returns HTTP::Response object.

head3 Parameters

=over 4

=item request

A L<FlowPDF::Client::ModernREST::HTTPRequest> object created by newRequest function.

=back

=head3 Returns 

=over 4

=item L<HTTP::Response> reference.

=back

=cut


sub doRequest {
    my ($self, $request) = @_;

    my $ua = $self->getUserAgent();
    # TODO: Maybe handle HTTP::Request here.
    my $req = $request->toHttpRequest();
    $req = $self->applyAuth($req);
    my $resp = $ua->request($req);
    return $resp;
}

sub applyAuth {
    my ($self, $request) = @_;

    # TODO: Check that request IS actually HTTP::Request;
    # TODO: Move auth logic to HTTPRequest package of ModernREST;
    my $auth = $self->getAuth();

    if (my $authType = $auth->getAuthType()) {
        my $values = $auth->getAuthValues();
        if ($authType eq 'basic') {
            $request->authorization_basic($values->{username}, $values->{password});
        }
    }
    return $request;
}


sub compileDefaultHeaders {
    my ($self) = @_;

    my $rv = [];

    if (!$self->getDefaultHeaders()) {
        return $rv;
    }

    my $defaultHeaders = $self->getDefaultHeaders();
    for my $k (keys %$defaultHeaders) {
        my $v = undef;
        if (ref $defaultHeaders->{$k} eq 'CODE') {
            $v = $defaultHeaders->{$k}();
        }
        # no handling for now for something other than CODE.
        else {
            $v = $defaultHeaders->{$k};
        }
        push @$rv, $k, $v;
    }

    return $rv;
}

sub getVariablesFromRequest {
    my ($self, $req) = @_;

    # TODO: Handle reques type here
    my $variables = {
        URN => $req->getUrn(),
        URL => $req->getBaseUrl(),
        CONTENT => $req->getContent() || 'test',
        METHOD => $req->getMethod()
        # HEADERS => $req->getHeaders()
    };
    if ($req->getHeaders()) {
        my %h = @{$req->getHeaders()};
        $variables->{HEADERS} = \%h;
    }
    $variables->{URI} = $variables->{URL} . '/' . $variables->{URN};
    return $variables;
}

sub compileRequestMappings {
    my ($self, $request) = @_;

    # TODO: Add mappings validation and throw an exception if mappings are invalid.
    # mappings should have the following fields: endpoint, headers, content and method
    if (!$self->getMappings()) {
        return $request;
    }
    my $variables = $self->getGlobalMappingVariables() || {};

    my $requestVariables = $self->getVariablesFromRequest($request);

    if ($requestVariables && ref $requestVariables eq 'HASH') {
        $variables = {%$variables, %$requestVariables}
    }
    my $mappings = $self->getMappings();
    my %mappings = %$mappings;
    $mappings = \%mappings;
    process_vars($mappings, $variables);
    return $mappings;
    # $request->setMappings($mappings);

    # return $request;
}


# Service Functions

sub process_vars {
    # $t stands for tree, $v stands for vars
    my ($t, $v) = @_;

    if (!ref $t) {
        return
    }
    elsif (ref $t eq 'HASH') {
        my @t_keys = keys %$t;
        if ($t->{'*'}) {
            my $replacement = find_replacement($t->{'*'}, $v);
            for my $k (keys %$replacement) {
               $t->{$k} = $replacement->{$k};
            }
            delete $t->{'*'};
        }
        for my $k (@t_keys) {
            next if $k eq '*';
            my $replacement = find_replacement($t->{$k}, $v);
            $t->{$k} = $replacement;
            process_vars($t->{$k}, $v);
        }
    }
    elsif (ref $t eq 'ARRAY') {
        return;
    }

}

sub find_replacement {
    my ($value, $variables) = @_;

    if (ref $value) {
        return $value;
    }
    # my $code = qq||;
    if ($value =~ m/^\$([A-Za-z0-9]+)$/s) {
        my $var_name = $1;
        $value = $variables->{$var_name};
    }
    elsif (my @r = $value =~ m/\$([A-Za-z0-9]+)/gms) {
        for my $v (@r) {
            $value =~ s/\$$v/$variables->{$v}/gms;
        }
    }
    return $value;
}


1;


