package Net::SMS::TWSMS;

use strict;
use Carp;
use LWP::UserAgent;

our $VERSION = '0.1';
our (@ISA) = qw(Exporter);
our (@EXPORT) = qw(send_sms);

sub new {
    my ($class, %params) = @_;
    my $self = {};
    bless $self, $class;
    $self->_init(%params) or return undef;
    return $self;
}

sub send_sms {
   return __PACKAGE__->new(
               username  => $_[0], 
               password  => $_[1],
               recipients=> [$_[2]],
          )->smsSend($_[3]);
}

sub baseurl {
   my $self = shift;
   if (@_) { $self->{"_baseurl"} = shift }
   return $self->{"_baseurl"};
}

sub username {
   my $self = shift;
   if (@_) { $self->{"_username"} = shift }
   return $self->{"_username"};
}

sub password {
   my $self = shift;
   if (@_) { $self->{"_password"} = shift }
   return $self->{"_password"};
}

sub login {
   my ($self, $user, $pass) = @_;
   $self->username($user) if($user);
   $self->password($pass) if($pass);
   return ($self->username, $self->password);
}

sub smsRecipient {
   my ($self, $recip) = @_;
   push @{$self->{"_mobile"}}, $recip if($recip);
   return $self->{"_mobile"};
}

sub smsMessage {
   my $self = shift;
   if (@_) { $self->{"_message"} = shift }
   return $self->{"_message"};
}

sub smsValidtime {
   my $self = shift;
   if (@_) { $self->{"_vldtime"} = shift }
   return $self->{"_vldtime"};
}	

sub smsDeliverydate {
   my $self = shift;
   if (@_) { $self->{"_dlvtime"} = shift }
   return $self->{"_dlvtime"};
}

sub smsType {
   my $self = shift;
   if (@_) { $self->{"_type"} = shift }
   return $self->{"_type"};
}

sub smsEncoding {
   my $self = shift;
   if (@_) { $self->{"_encoding"} = shift }
   return $self->{"_encoding"};
}

sub smsPopup {
   my $self = shift;
   if (@_) { $self->{"_popup"} = shift }
   return $self->{"_popup"};
}

sub smsMo {
   my $self = shift;
   if (@_) { $self->{"_mo"} = shift }
   return $self->{"_mo"};	
}

sub smsWapUrl {
   my $self = shift;
   if (@_) { $self->{"_wapurl"} = shift }
   return $self->{"_wapurl"};
}

sub is_success {
   my $self = shift;
   return $self->{"_success"};
}

sub successcount {
   my $self = shift;
   return $self->{"_successcount"};
}

sub resultcode {
   my $self = shift;
   return $self->{"_resultcode"};
}

sub resultmessage {
   my $self = shift;
   my %ERR_DESCRIPTION = ( '-1' => 'Send SMS fail',
			   '-2' => 'Username or password incorrect',
			   '-3' => 'TAG:popup incorrect',
			   '-4' => 'TAG:mo incorrect',
			   '-5' => 'TAG:encoding incorrect',
			   '-6' => 'TAG:mobile incorrect',
			   '-7' => 'TAG:message incorrect',
			   '-8' => 'TAG:vldtime incorrect',
			   '-9' => 'TAG:dlvtime incorrect',
			   '-10' => 'Deficient quota of send SMS',
			   '-11' => 'Account disabled',
			   '-12' => 'TAG:type incorrect',
			   '-13' => 'Do not use TAG:type=dlv when use wap push',
			   '-14' => 'Source IP haven\'t permission to use',
			   '-99' => 'System Error (If show the error , please contact Call Center)'
			);   	
   return $ERR_DESCRIPTION{$self->{"_resultcode"}} ? $ERR_DESCRIPTION{$self->{"_resultcode"}} : $self->{"_resultmessage"}; 
    
}

sub smsSend {
   my ($self, $message) = @_;
   $self->smsMessage($message) if($message);
   my $parms = {};

   #### Check for mandatory input
   foreach(qw/username password mobile message type encoding/) {
      $self->_croak("$_ not specified.") unless(defined $self->{"_$_"});
      if($_ eq 'mobile') {
         $parms->{$_} = join(",", @{$self->{"_$_"}});
      } else {
         $parms->{$_} = $self->{"_$_"};
      }
   }

   # Type can be now/dlv
   $self->_croak("Invalid type") 
      unless($self->smsType =~ /^(now|dlv)$/);

   # delivery? We must have a Date that format: YYYYMMDDHHmm (example:200606130830)
   if($self->smsType eq 'dlv') {
      $self->_croak("No delivery date specified.") unless($self->smsDlvtime);
   }

   # Encoding can be now/dlv
   $self->_croak("Invalid encoding") 
      unless($self->smsEncoding =~ /^(big5|ascii|unicode|push|unpush)$/);

   # Wappush? We must have an URL
   if(($self->smsEncoding eq 'push') or ($self->smsEncoding eq 'unpush')) {
      $self->_croak("No wapurl specified.") unless($self->smsWapUrl);
   }

   # Append the additional arguments
   foreach(qw/dlvtime vldtime popup mo wapurl/) {
         $parms->{$_} = $self->{"_$_"} if(defined $self->{"_$_"});
   }

   # Should be ok now, right? Let's send it!
   my $res = $self->{"_ua"}->post($self->baseurl, $parms);

   if($res->is_success) {
      my $CheckRes = $1 if ($res->decoded_content =~ m/msgid=(.*)/);

      # Set the return info
      $self->{"_resultcode"} = $CheckRes;

      # Successful?
      if($CheckRes <= 0) {
         $self->{"_successcount"} = 0;
         $self->{"_success"} = 0;
         $self->{"_resultmessage"} = $self->resultmessage();
      } else {
         $self->{"_successcount"} = 1;
         $self->{"_success"} = 1;
         $self->{"_resultmessage"} = "MSGID:$CheckRes";
      }
   } else {
      $self->{"_resultcode"} = -999;
      $self->{"_resultmessage"} = $res->status_line;
   }
   return $self->is_success;
}


####################################################################
sub _init {
   my $self   = shift;
   my %params = @_;

   my $ua = LWP::UserAgent->new(
      agent => __PACKAGE__." v. $VERSION",
   );

   # Set/override defaults
   my %options = (
      ua                => $ua,
      baseurl           => 'http://api.twsms.com/send.php',
      username          => undef,	#	帳號
      password          => undef,	#	密碼
      mobile		=> [],		#	收訊者
      message           => undef,	#	簡訊內容

      vldtime		=> '86400',	#	有效時間 valid time
      dlvtime		=> undef,	#	預約時間 delivery date
      type              => 'now',	#	now =>立即發送, dlv => 預約發送
      encoding		=> 'big5',	#	big5, ascii, unicode, push, unpush
      mo		=> undef,	#	
      popup		=> undef,	#
      wapurl		=> undef,	#

      success           => undef,	#
      successcount      => undef,	#
      resultcode        => undef,	#
      resultmessage     => undef,	#
      %params,
   );
   $self->{"_$_"} = $options{$_} foreach(keys %options);
   return $self;
}


sub _croak {
   my ($self, @error) = @_;
   Carp::croak(@error);
}
1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Net::SMS::TWSMS - Send SMS messages via the www.twsms.com service.

=head1 SYNOPSIS

  use strict;
  use Net::SMS::TWSMS;

  my $sms = new Net::SMS::TWSMS;
     $sms->login('username', 'p4ssw0rd');
     $sms->smsRecipient('0912345678');
     $sms->smsSend("The SMS be send by TWSMS Service!");

  if($sms->is_success) {
     print "Successfully sent message to ".$sms->successcount." number!\n";
  } else {
     print "Something went horribly wrong!\n".
           "Error: ".$sms->resultmessage." (".$sms->resultcode.")".
  }

or, if you like one liners:

  perl -MNet::SMS::TWSMS -e 'send_sms("twsms_username", "twsms_password", "recipient", "messages text")'


=head1 DESCRIPTION

Net::SMS::TWSMS allows sending SMS messages via L<http://www.twsms.com/>

=head1 METHODS

=head2 new

new creates a new Net::SMS::TWSMS object.

=head2 Options

=over 4

=item baseurl

Defaults to L<http://api.twsms.com/send.php>, but could be set to,
for example, the SSL URL L<https://api.twsms.com/send.php>.

=item ua

Configure your own L<LWP::UserAgent> object, or use our default one.

=item username

Your twsms.com username

=item password

Your twsms.com password

=item smsMessage

The actual SMS text

=item smsType

Defaults to I<now>, but could be set to I<dlv>

I<now> mean send SMS now. 
I<dlv> mean send SMS at a delivery date.

=item smsPopup

Defaults to I<undef>, but could be set to I<1>

if smsPopup = 1 

mean the SMS context will show on the screen of Receiver's mobile phone,

but will not save into Receiver's mobile phone.

=item smsMo

Defaults to I<undef>, but could be set to I<y>

=item smsEncoding

Defaults to I<big5>, but could be set to I<ascii>, I<unicode>, I<push>, or I<unpush> 

I<big5>:    the SMS context in Chinese or Engilsh, the max of SMS context length is 70 character.
I<ascii>:   the SMS context in Engilsh, the max of SMS context length is 160 character.
I<unicode>: the SMS context in Unicode.
I<push>:    the max length of SMS context + WapUrl is 88 Bytes
            A half witdh of alphanumeric is 1 byte
            A full withd of alphanumeric or a Chinese word is 3 Bytes
I<unpush>:  as push

=item smsValidtime

Defaults to I<86400>

SmsVldtime mean the available time of SMS.

Its unit in sec. Example: 86400 (mean 24 hours)

=item smsDeliverydate

SmsDlvtime mean send SMS at a reserved time.

Its format is YYYYMMDDHHII.

Example: 200607291730  (mean 2006/07/29 17:30)

=back

All these options can be set at creation time, or be set later, like this:

  $sms->username('my_username');
  $sms->password('my_password');
  $sms->smsType('push');
  $sms->smsWapUrl('http://wap_url');

=head2 login

Set the I<username> and I<password> in one go. 

  $mollie->login('my_twsms_username', 'my_twsms_password');

  # is basically a shortcut for

  $mollie->username('my_twsms_username');
  $mollie->password('my_twsms_password');

Without arguments, it will return the array containing I<username>,
and I<password>.

   my ($username, $password) = $sms->login();

=head2 smsRecipient

Push a phone number in the I<mobile> variable

     $sms->recipient('0912345678');

=head2 smsSend

Send the actual message. If this method is called with an argument,
it's considered the I<message>. Returns true if the sending was successful,
and false when the sending failed (see I<resultcode> and I<resultmessage>).

=head2 is_success

Returns true when the last sending was successful and false when it failed.

=head2 resultcode

Returns the resulting code, as provided by twsms.com. See the API document
L<http://www.twsms.com/dl/api_doc.zip> for all possible codes.

When L<LWP::UserAgent> reports an error, the I<resultcode> will be
set to C<-999>.

=head2 resultmessage

Returns the result message, as provided by twsms.com, or L<LWP::UserAgent>.


=head2 EXPORT

None by default.



=head1 SEE ALSO

The API document of TWSMS

http://www.twsms.com/dl/api_doc.zip

=head1 WEBSITE

You can find information about TWSMS at :

   http://www.twsms.com/

=head1 AUTHOR

Tsung-Han Yeh, E<lt>snowfly@yuntech.edu.twE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Tsung-Han Yeh

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut


