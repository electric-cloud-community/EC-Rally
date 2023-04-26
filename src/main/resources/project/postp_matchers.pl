use ElectricCommander;

push(
    @::gMatchers,

    {
       id      => "error",
       pattern => q{^Error:\s(.+)},
       action  => q{
         
                              my $desc = ((defined $::gProperties{"summary"}) ? $::gProperties{"summary"} : '');

                              $desc .= "Error: \'$1\'";
                              
                              setProperty("summary", $desc . "\n");
                              incValue("errors");
                             },
    },

    {
       id      => "warning",
       pattern => q{^Warning:\s(.+)},
       action  => q{
         
                              my $desc = ((defined $::gProperties{"summary"}) ? $::gProperties{"summary"} : '');

                              $desc .= "Warning: \'$1\'";
                              
                              setProperty("summary", $desc . "\n");
                              incValue("warnings"); diagnostic("",
                                    "warning", -4);
                                    
                             },
    },
    {
       id      => "reference",
       pattern => q{^Object\sreference:\s(.+)},
       action  => q{
         
                              my $desc = ((defined $::gProperties{"summary"}) ? $::gProperties{"summary"} : '');

                              $desc .= "Object Reference: \'$1\'";
                              
                              setProperty("summary", $desc . "\n");
                             },
    },

    {
       id      => "host",
       pattern => q{^Adding\sconfig\srally_url\s=\s(.+)},
       action  => q{
         
                              my $desc = ((defined $::gProperties{"summary"}) ? $::gProperties{"summary"} : '');

                              $desc .= "Server: \'$1\'";
                              
                              setProperty("summary", $desc . "\n");
                             },
    },

    {
       id      => "json",
       pattern => q{^For\scomplete\sJSON\sresponse,\s.+\'(.+)\'.+},
       action  => q{
         
                              my $desc = ((defined $::gProperties{"summary"}) ? $::gProperties{"summary"} : '');

                              $desc .= "Check property: \'$1\'";
                              
                              setProperty("summary", $desc . "\n");
                             },
    },
    {
       id      => "Object",
       pattern => q{^(Reading|Updating|Deleting)\sobject\s(.+)},
       action  => q{
         
                              my $desc = ((defined $::gProperties{"summary"}) ? $::gProperties{"summary"} : '');

                              $desc .= "Object: \'$2\'";
                              
                              setProperty("summary", $desc . "\n");
                             },
    },

);
