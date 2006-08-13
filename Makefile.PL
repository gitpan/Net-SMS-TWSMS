use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Net::SMS::TWSMS',
    DISTNAME          => 'Net-SMS-TWSMS',
    VERSION_FROM      => 'lib/Net/SMS/TWSMS.pm', # finds $VERSION
    PREREQ_PM         => {
            'LWP::UserAgent'              => 2.033,
            'Test::Simple'                => 0.44,
    }, 
    ($] >= 5.006 ?     ## Add these new keywords supported since 5.006
      (ABSTRACT_FROM  => 'lib/Net/SMS/TWSMS.pm', # retrieve abstract from module
       AUTHOR         => 'Tsung-Han Yeh <snowfly@yuntech.edu.tw>') : ()),
);
