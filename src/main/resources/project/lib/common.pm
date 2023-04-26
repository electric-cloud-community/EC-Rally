# -------------------------------------------------------------------------
# Package
#    common
#
# Dependencies
#    None
#
# Purpose
#    Common module for EC-Rally plugin
#
# Copyright (c) 2014 Electric Cloud, Inc.
# All rights reserved
# -------------------------------------------------------------------------
package common;

use Cwd;
use strict;
use warnings;
use ElectricCommander;
use Encode;



# -------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------

my $DEFAULT_DEBUG = 1;
my $ERROR         = 1;
my $SUCCESS       = 0;

$::browser = LWP::UserAgent->new(agent => 'perl LWP', cookie_jar => {});    # used to hold the main browser object

# Constructor
sub new {
    my $class = shift;

    #attributes
    my $self = {
                 _cmdr => shift,
                 _opts => shift,
               };
    bless $self, $class;
    return $self;
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
# ecode - Get exit code
#
# Arguments:
#   -
#
# Returns:
#   exit code number
#
########################################################################
sub ecode {
    my ($self) = @_;
    return $self->opts()->{exitcode};
}

########################################################################
# createUrl - Creates a URL to the RALLY Server
#
# Arguments:
#   'create' or Rally objectId
#
# Returns:
#   URL to be queried
#
########################################################################
sub createUrl {
    my $self   = shift;
    my $objectType = shift;
    my $ending = shift;

    ## Create url for request
    $self->debugMsg(1, 'Creating REST url...');

    ## Structure: https://HOST/slm/webservice/API/ObjectType/
    my $url_request = $self->opts->{rally_url} . "/slm/webservice/" . $self->opts->{api_version} . "/" . $objectType . $ending;
    $self->debugMsg(2, 'URL: ' . $url_request);
    return $url_request;

}

########################################################################
# restRequest - issue the HTTP request, do special processing, and return result
#
# Arguments:
#   req      - the HTTP req
#
# Returns:
#   response - the HTTP response
########################################################################
sub restRequest {
    my ($self, $postType, $urlText, $contentType, $content) = @_;

    my $url;
    my $req;
    my $response;

    ## Check url
    if ($urlText eq "") {
        $self->debugMsg(0, "Error: blank URL in restRequest.");
        $self->opts->{exitcode} = $ERROR;
        return "";
    }

    ## Set Request Method
    $url = URI->new($urlText);
    if ($postType eq "POST") {
        $req = HTTP::Request->new(POST => $url);
    }
    elsif ($postType eq "DELETE") {
        $req = HTTP::Request->new(DELETE => $url);
    }
    elsif ($postType eq "PUT") {
        $req = HTTP::Request->new(PUT => $url);
    }
    else {
        $req = HTTP::Request->new(GET => $url);
    }

    # Create authorization to server, depending of credential type
    if ($self->opts->{credentialType} ne 'password') {
        # Authorize by API key
        $req->header("zsessionid" => $self->opts->{rally_pass});
    } else {
        # Legacy BASIC authorization
        $req->authorization_basic($self->opts->{rally_user}, $self->opts->{rally_pass});
    }

    ## Set Request Content type
    if ($contentType ne "") {
        $req->content_type($contentType);
    }
    ## Set Request Content
    if ($content && $content ne "") {
        if (defined($content) && utf8::is_utf8($content)) {
            $req->content(encode_utf8($content));
        }
        else {
            $req->content($content);
        }
    }

    ## Print Request
    $self->debugMsg(2, "HTTP Request:\n" . $req->as_string);

    ## Make Request
    $response = $::browser->request($req);

    ## Print Response
    $self->debugMsg(1, "HTTP Response:\n" . $response->decoded_content);


    ## Check for errors
    if ($response->is_error) {
        $self->debugMsg(0, $response->status_line);
        $self->getError($response->decoded_content);
        $self->opts->{exitcode} = $ERROR;
        return ('{}');
    }

    ## Return Response
    my $json = $response->content;
    return $json;
}

########################################################################
# debugMsg - Print a debug message
#
# Arguments:
#   errorlevel - number compared to $self->opts->{debug}
#   msg        - string message
#
# Returns:
#   -
#
########################################################################
sub debugMsg {
    my ($self, $errlev, $msg) = @_;
    if ($self->opts->{debug} >= $errlev) { print "$msg\n"; }
    return;
}

########################################################################
# getError - Print a detailed error message
#
# Arguments:
#   error      - response content
#
# Returns:
#   -
#
########################################################################
sub getError {
    my ($self, $error) = @_;

    # Looks like the error message is an html page
    # Emit the HTML page for lack of better option
    $self->debugMsg(0, 'Error: ' . $error . "\n");
    return;
}

########################################################################
# create - Override this method in the child class
########################################################################
sub create {
    my $self = shift;
    print "Override this function";
}

########################################################################
# read - Override this method in the child class
########################################################################
sub read {
    my $self = shift;
    print "Override this function";
}

########################################################################
# update - Override this method in the child class
########################################################################
sub update {
    my $self = shift;
    print "Override this function";
}

########################################################################
# delete - Override this method in the child class
########################################################################
sub delete {
    my $self = shift;
    print "Override this function";
}

########################################################################
# query - Override this method in the child class
########################################################################
sub query {
    my $self = shift;
    print "Override this function";
}

1;
