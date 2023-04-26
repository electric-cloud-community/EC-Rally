package FlowPDF::Client::ModernREST::HTTPRequest;

use base qw/FlowPDF::BaseClass2/;
use FlowPDF::Types;

use strict;
use warnings;
use Carp;
use HTTP::Request;
use URI::Split qw/uri_join/;


__PACKAGE__->defineClass({
    baseUrl => FlowPDF::Types::Scalar(),
    method => FlowPDF::Types::Scalar(),
    urn => FlowPDF::Types::Scalar(),
    proxyComponent => FlowPDF::Types::Reference('FlowPDF::Component::Proxy'),
    headers => FlowPDF::Types::Reference('ARRAY'),
    content => FlowPDF::Types::Any(),
    mappings => FlowPDF::Types::Reference('HASH'),
    variables => FlowPDF::Types::Reference('HASH')
});

sub _new {
    my ($class, $method, $uri, $headers, $content) = @_;

    # TODO: Rewrite to be using flowpdf exceptions
    if (!$method || !$uri) {
        croak "method and uri are mandatory";
    }
    my $self = $class->SUPER::new({
        headers => $headers,
        urn => $uri
    });
    if ($headers) {
        $self->setHeaders($headers);
    }
    if ($content) {
        # TODO: add automatical encoding if it is acceptable
        $self->setContent($content);
    }
    $self->setMethod($method);
    $self->setUrn($uri);
    return $self;
}


sub getAbsoluteAddress {
    my ($self) = @_;

    # my $rv = uri_join($self->getBaseUrl(), $self->getUrn());
    my $urn = $self->getUrn();

    my $baseUrl = $self->getBaseUrl();
    $baseUrl =~ s|\/+$||;
    $urn =~ s|^/+||;
    my $rv = join('/', $baseUrl, $urn);
    return $rv;
}


sub toHttpRequest {
    my ($self) = @_;

    # at this moment mappings are already compiled
    my $mappings = $self->getMappings();
    my @callParams = ();
    # mappings are present, so using the mappings
    if ($mappings) {
        my $method = $mappings->{method};
        my $uri = $mappings->{endpoint};

        @callParams = ($method => $uri);

        if ($mappings->{headers}) {
            my $headers = headersToArrayRef($mappings->{headers});
            push @callParams, $headers;
        }
        if ($mappings->{content}) {
            push @callParams, $mappings->{content};
        }
    }
    else {
        my $method = $self->getMethod();
        my $urn = $self->getUrn();
        my $absAddress = $self->getAbsoluteAddress($urn);
        @callParams = ($method, $absAddress);
        if ($self->getHeaders()) {
            push @callParams, $self->getHeaders();
        }
        if (my $headers = $self->getContent()) {
            push @callParams, $headers;
        }

    }

    # TODO: Decide on precedence of execution. What should go first, proxy, or mappings?
    my $req = HTTP::Request->new(@callParams);
    if (my $proxy = $self->getProxyComponent()) {
        $req = $proxy->augment_request($req);
    }
    return $req;
}


sub header {
    my ($self, $header, $value) = @_;
    return $self;
}

sub content {
    my ($self, $content) = @_;
}

sub headersToArrayRef {
    my ($headers) = @_;

    my $rv = [];
    # TODO: Check for reference later.
    for my $k (keys %$headers) {
        my $v = $headers->{$k};
        push @$rv, $k, $v;
    }

    return $rv;
}

1;
