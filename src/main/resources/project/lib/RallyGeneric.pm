package RallyGeneric;

use strict;
use warnings;
use CGI qw/:standard/;
use JSON qw(decode_json);
our @ISA = qw(common);

# -------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------

my $DEFAULT_DEBUG = 1;
my $ERROR         = 1;
my $SUCCESS       = 0;

########################################################################
# new - Object constructor for RallyGeneric
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

    ## Attributes
    my $self = $class->SUPER::new(shift, shift);
    bless $self, $class;
    return $self;
}

########################################################################
# create - Create an Object using REST
########################################################################
sub create {
    my $self = shift;

    my $url;
    my $json_result;
    my $ob_name;
    my $ob_type;
    my $ob_ref;

    $self->debugMsg(0, 'Creating object.');

    my $ending = '/create';
    if ($self->opts->{credentialType} eq 'password') {
        my $token = $self->getSecurityToken();
        $ending .= "?key=$token"; 
    }
    
    $url = $self->createUrl($self->opts->{rally_object_type}, $ending);

    if ($self->ecode) { return; }

    ## Make PUT request
    $json_result = decode_json($self->restRequest('PUT', $url,
                               qq{text/javascript; charset=utf-8},
                               $self->opts->{rally_data}));

    ## Check for warnings
    $self->checkForWarnings($json_result->{'CreateResult'});

    ## Check for errors
    return unless $self->checkForErrors($json_result->{'CreateResult'}) == 0;

    #
    # Sample data
    #{
    #     "CreateResult": {
    #         "_rallyAPIMajor": "2",
    #         "_rallyAPIMinor": "0",
    #         "Errors": [],
    #         "Warnings": [],
    #         "Object": {
    #             "_rallyAPIMajor": "2",
    #             "_rallyAPIMinor": "0",
    #             "_ref": "https://rally1.rallydev.com/slm/webservice/v2.0/builddefinition/20255775694",
    #             "_refObjectUUID": "e260f5f2-7255-454e-b7c4-4ca30a813a45",
    #             "_objectVersion": "1",
    #             "_refObjectName": "ElectricCommander Build",
    #             "_CreatedAt": "just now",
    #             "ObjectID": 20255775694,
    #             "VersionId": "1",
    #             "_type": "BuildDefinition"
    #         }
    #     }
    # }

    ## Get Object Information
    $ob_name = $json_result->{'CreateResult'}->{'Object'}->{'_refObjectName'};
    $ob_type = $json_result->{'CreateResult'}->{'Object'}->{'_type'};
    $ob_ref  = $json_result->{'CreateResult'}->{'Object'}->{'_ref'};

    ## Print Object info
    $self->debugMsg(0, '-----------------------------------------------------------------');
    $self->debugMsg(0, 'Object succesfully created!');
    $self->debugMsg(0, '');
    $self->debugMsg(0, 'OBJECT INFO');
    $self->debugMsg(0, 'Object Name: ' . $ob_name);
    $self->debugMsg(0, 'Object type: ' . $ob_type);
    $self->debugMsg(0, 'Object reference: ' . $ob_ref);

    ## Return Response
    return $json_result;
}

########################################################################
# read - Read an Object using REST
########################################################################
sub read {
    my $self = shift;

    my $count;
    my $objectId;
    my $url;
    my $json_result;

    ## Get ObjectID
    if (defined($self->opts->{use_formattedId}) && $self->opts->{use_formattedId} eq 1) {
        $self->opts->{rally_queryString} = "(FormattedID = " . $self->opts->{rally_ID} . ")";

        $json_result = $self->query($self->opts());
        if ($self->ecode) { return; }

        # Check query result count
        $count = $json_result->{'QueryResult'}->{'TotalResultCount'};
        if ($count eq '0') {
            $self->debugMsg(0, 'Error: No Object with FormattedID ' . $self->opts->{rally_ID});
            $self->opts->{exitcode} = $ERROR;
            return;
        }

        #
        # Sample data
        #{
        #    "QueryResult": {
        #        "_rallyAPIMajor": "2",
        #        "_rallyAPIMinor": "0",
        #        "TotalResultCount": 1,
        #        "StartIndex": 1,
        #        "PageSize": 20,
        #        "Results": [
        #            {
        #                "_ref": "https://rally1.rallydev.com/slm/webservice/v2.0/tag/34239",
        #                "Name": "Tag 1"
        #            }
        #        ]
        #    }
        #}

        # Get ID from reference
        $objectId = $json_result->{'QueryResult'}->{'Results'}[0]->{'_ref'};
        $objectId =~ s/.*\/([A-Za-z0-9_])/$1/ixsmg;
    }
    else {
        $objectId = $self->opts->{rally_ID};
    }

    ## Create REST URL
    $self->debugMsg(0, 'Reading object ' . $self->opts->{rally_ID});
    $url = $self->createUrl($self->opts->{rally_object_type},'/' . $objectId);
    if ($self->ecode) { return; }

    ## Make GET request
    $json_result = decode_json($self->restRequest('GET', $url, qq{text/javascript; charset=utf-8}, ""));

    ## Check for warnings
    $self->checkForWarnings($json_result);

    ## Check for errors
    return unless $self->checkForErrors($json_result) == 0;

    ## Print Result info
    $self->debugMsg(0, '-----------------------------------------------------------------');
    $self->debugMsg(0, 'Object ' . $self->opts->{rally_ID} . ' succesfully read!');

    ## Return Response
    return $json_result;
}

########################################################################
# update - Update an Object using REST
########################################################################
sub update {
    my $self = shift;

    my $json_result;
    my $count;
    my $objectId;
    my $url;

    ## Get ObjectID
    if (defined($self->opts->{use_formattedId}) && $self->opts->{use_formattedId} eq 1) {
        $self->opts->{rally_queryString} = "(FormattedID = " . $self->opts->{rally_ID} . ")";

        $json_result = $self->query();
        if ($self->ecode) { return; }

        ## Check query result count

        $count = $json_result->{'QueryResult'}->{'TotalResultCount'};
        if ($count eq '0') {
            $self->debugMsg(0, 'Error: No Object with FormattedID ' . $self->opts->{rally_ID});
            $self->opts->{exitcode} = $ERROR;
            return;
        }

        ## Get ID from reference
        $objectId = $json_result->{'QueryResult'}->{'Results'}[0]->{'_ref'};
        $objectId =~ s/.*\/([A-Za-z0-9_])/$1/ixsmg;

    }
    else {

        $objectId = $self->opts->{rally_ID};
    }


    my $ending = "/$objectId";
    if ($self->opts->{credentialType} eq 'password') {
        my $token = $self->getSecurityToken();
        $ending .= "?key=$token"; 
    }
    
    ## Create REST URL
    $self->debugMsg(0, 'Updating object ' . $self->opts->{rally_ID});
    $url = $self->createUrl($self->opts->{rally_object_type}, $ending);
    if ($self->ecode) { return; }

    ## Make POST request
    $json_result = decode_json($self->restRequest('POST', $url, qq{text/javascript; charset=utf-8}, $self->opts->{rally_data}));

    ## Check for warnings
    $self->checkForWarnings($json_result->{'OperationResult'});

    ## Check for errors
    return unless $self->checkForErrors($json_result->{'OperationResult'}) == 0;

    ## Print Result info
    $self->debugMsg(0, '-----------------------------------------------------------------');
    $self->debugMsg(0, 'Object ' . $self->opts->{rally_ID} . ' succesfully updated!');

    ## Return Response
    return $json_result;
}

########################################################################
# delete - Delete an Object using REST
########################################################################
sub delete {
    my $self = shift;

    my $json_result;
    my $count;
    my $objectId;
    my $url;

    ## Get ObjectID
    if (defined($self->opts->{use_formattedId}) && $self->opts->{use_formattedId} eq 1) {
        $self->debugMsg(0, 'Getting ObjectID from object ' . $self->opts->{rally_ID});
        $self->opts->{rally_queryString} = "(FormattedID = " . $self->opts->{rally_ID} . ")";
        $json_result = $self->query();
        if ($self->ecode) { return; }

        ## Check query result count
        $count = $json_result->{'QueryResult'}->{'TotalResultCount'};
        if ($count eq '0') {
            $self->debugMsg(0, 'Error: No Object with FormattedID ' . $self->opts->{rally_ID});
            $self->opts->{exitcode} = $ERROR;
            return;
        }

        ## Get ID from reference
        $objectId = $json_result->{'QueryResult'}->{'Results'}[0]->{'_ref'};
        $objectId =~ s/.*\/([A-Za-z0-9_])/$1/ixsmg;

    }
    else {

        $objectId = $self->opts->{rally_ID};
    }

    my $ending = "/$objectId";
    if ($self->opts->{credentialType} eq 'password') {
        my $token = $self->getSecurityToken();
        $ending .= "?key=$token"; 
    }
    
    ## Create REST URL
    $self->debugMsg(0, 'Deleting object ' . $self->opts->{rally_ID});
    $url = $self->createUrl($self->opts->{rally_object_type}, $ending);
    if ($self->ecode) { return; }

    ## Make DELETE request
    $json_result = decode_json($self->restRequest('DELETE', $url, qq{text/javascript; charset=utf-8}, ""));

    ## Check for warnings
    $self->checkForWarnings($json_result->{'OperationResult'});

    ## Check for errors
    return unless $self->checkForErrors($json_result->{'OperationResult'}) == 0;

    ## Print Result info
    $self->debugMsg(0, '-----------------------------------------------------------------');
    $self->debugMsg(0, 'Object ' . $self->opts->{rally_ID} . ' succesfully deleted!');

    ## Return Response
    return $json_result;
}

########################################################################
# query - Query an Object using REST
########################################################################
sub query {
    my $self = shift;

    my $query_url;
    my $url;
    my $query_error;
    my $ob_name;
    my $ob_type;
    my $ob_ref;
    my @args = ();
    my $json_result;

    ## Check existing parameters
    if (defined($self->opts->{rally_queryString}) && $self->opts->{rally_queryString} ne '') {
        push(@args, "?query=" . $self->opts->{rally_queryString});
    }
    else {
        push(@args, "?");
    }
    if (defined($self->opts->{rally_orderString}) && $self->opts->{rally_orderString} ne '') {
        push(@args, "&order=" . $self->opts->{rally_orderString});
    }
    if (defined($self->opts->{rally_pageSize}) && $self->opts->{rally_pageSize} ne '') {
        push(@args, "&pagesize=" . $self->opts->{rally_pageSize});
    }
    if (defined($self->opts->{rally_startIndex}) && $self->opts->{rally_startIndex} ne '') {
        push(@args, "&start=" . $self->opts->{rally_startIndex});
    }
    if (defined($self->opts->{rally_fullObject}) && $self->opts->{rally_fullObject} ne '') {
        push(@args, "&fetch=" . $self->opts->{rally_fullObject});
    }
    if (defined($self->opts->{rally_workspace}) && $self->opts->{rally_workspace} ne '') {
        if (!defined($self->opts->{rally_project}) || $self->opts->{rally_project} eq '') {
            push(@args, "&workspace=" . $self->opts->{rally_workspace});
        }
    }
    if (defined($self->opts->{rally_project}) && $self->opts->{rally_project} ne '') {
        push(@args, "&project=" . $self->opts->{rally_project});

        if (defined($self->opts->{rally_projectScopeUp}) && $self->opts->{rally_projectScopeUp} ne '') {
            push(@args, "&projectScopeUp=" . $self->opts->{rally_projectScopeUp});
        }
        if (defined($self->opts->{rally_projectScopeDown}) && $self->opts->{rally_projectScopeDown} ne '') {
            push(@args, "&projectScopeDown=" . $self->opts->{rally_projectScopeDown});
        }
    }

    ## Create Query URL
    $query_url = join("", @args);

    ## Create REST URL
    $self->debugMsg(0, 'Executing ' . $query_url) if ($self->opts->{method} eq 'query');
    $url = $self->createUrl($self->opts->{rally_object_type} ,$query_url);
    if ($self->ecode) { return; }

    ## Make GET request
    $json_result = decode_json($self->restRequest('GET', $url, qq{text/javascript; charset=utf-8}, ""));

    ## Check for warnings
    $self->checkForWarnings($json_result->{'QueryResult'});


    ## Check for Query errors
    return unless $self->checkForErrors($json_result->{'QueryResult'}) == 0;

    if ($self->opts->{method} eq 'query') {
        $self->debugMsg(0, '-----------------------------------------------------------------');
        $self->debugMsg(0, 'Query succesfully executed!');
        $self->debugMsg(0, '');
        $self->debugMsg(0, 'OBJECTS INFO');

        my $array = $json_result->{'QueryResult'}->{'Results'};
        for my $node (@$array) {

            $ob_name = $node->{'_refObjectName'};
            $ob_type = $node->{'_type'};
            $ob_ref  = $node->{'_ref'};

            ## Print Object info

            $self->debugMsg(0, 'Object Name: ' . $ob_name);
            $self->debugMsg(0, 'Object type: ' . $ob_type);
            $self->debugMsg(0, 'Object reference: ' . $ob_ref);
            $self->debugMsg(0, '');

        }

    }

    ## Return Response
    return $json_result;
}

########################################################################
# checkForWarnings - Checks object for warnings and emits message if
#                    warning is found
# Input:
#   json_result: The json result from Rally
#
# Side effect:
#   Emits warning message if one exists
########################################################################
sub checkForWarnings {

    my $self = shift;
    my $json_result = shift;
    my $warning = $json_result->{'Warnings'}[0];
    if ($warning) {
        $self->debugMsg(0, 'Warning: ' . $warning);
    }
}

########################################################################
# checkForErrors - Checks object for error and emits message if
#                  error is found
# Input:
#   json_result: The json result from Rally
#
# Output:
#    0  - success, no errors
#    1  - failure, error present
# Side effect:
#   Emits error message if one exists
########################################################################
sub checkForErrors {

    my $self = shift;
    my $json_result = shift;
    my $error = $json_result->{'Errors'}[0];
    if ($error) {
        $self->debugMsg(0, 'Error: ' . $error);
        $self->opts->{exitcode} = $ERROR;
        return 1;
    }

    return 0;
}

########################################################################
# getSecurityToken - Issues a call to get a security token for
#                    POST/PUT/DELETE calls
#
# More information: https://rally1.rallydev.com/slm/doc/webservice/
# Input:
#   json_result: The json result from Rally
#
# Output:
#  string: The security token
#  undef on error
########################################################################
sub getSecurityToken {

    my $self = shift;

    # Create URL
    my $urlSecurityToken = $self->createUrl('security', '/authorize');

    # Check for error
    if ($self->ecode) { return undef; }

    my $json_result = decode_json($self->restRequest('GET',
                        $urlSecurityToken, qq{text/javascript; charset=utf-8}));

    return $json_result->{'OperationResult'}->{'SecurityToken'};
}

1;
