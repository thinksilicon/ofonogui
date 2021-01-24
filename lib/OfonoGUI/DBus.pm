package OfonoGUI::DBus;

use strict;
use warnings;
#use diagnostics;
use experimental 'smartmatch';

use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK );

require Exporter;
@ISA = qw( Exporter );
@EXPORT =qw(
	get_status
	get_modems
	get_modem_info
	get_Calls
	answer_Call
	number_Call
	hangup_Call
	send_Tone
);

our $VERSION = '0.1';

use Net::DBus;

use Data::Dumper;

sub _get_Interface {
	my $self = shift;
	my $interface = shift;
	my $path = shift || $self->{default_modem};
	
	return $self->{ofono}->get_object( $path, "org.ofono.".$interface );
}

sub _get_NetworkRegistration {
	my $self = shift;

	$self->{status} = $self->_get_Interface( "NetworkRegistration" )->GetProperties();
}

sub get_status {
	my $self = shift;

	$self->_get_NetworkRegistration();
	return $self->{status};
}

sub get_modems {
	my $self = shift;

	my @modems = $self->{manager}->GetModems();

	$self->{modems} = \@modems;
	$self->{default_modem} = $modems[0][0][0];
	$self->{default_modem_info} = $modems[0][0][1];

	return defined( $self->{default_modem} );
}

sub get_modem_info {
	my $self = shift;

	return $self->{default_modem_info};
}

sub get_Calls {
	my $self = shift;

	my @calls = $self->_get_Interface( "VoiceCallManager" )->GetCalls();

	if( defined( $calls[0][0][1] ) ) {
		$self->{calls}->{path} = $calls[0][0][0];
		$self->{calls}->{active} = $calls[0][0][1];
#print Dumper( $self->{calls} );
		return 1;
	}

	$self->{calls}->{active} = {};
	return 0;
}

sub get_activeCalls {
	my $self = shift;
	return $self->{calls}->{active};
}

sub answer_Call {
	my $self = shift;

	if( $self->{calls}->{active}->{State} eq 'incoming' ) {
		$self->_get_Interface( "VoiceCall", $self->{calls}->{path} )->Answer();
		return 1;
	}
	return 0;
}

sub number_Call {
	my $self = shift;
	my $number = shift;

	$self->{calls}->{outgoing} = $self->_get_Interface( "VoiceCallManager" )->Dial( $number, "default" );
	if( $self->{calls}->{outgoing} ) {
		return 1;
	}
	return 0;
}

sub get_outgoing {
	my $self = shift;
	return $self->{calls}->{outgoing};
}

sub hangup_Call {
	my $self = shift;

	if( $self->{calls}->{outgoing} ) {
		$self->_get_Interface( "VoiceCallManager" )->HangupAll();
		$self->{calls}->{outgoing} = 0;

		return 1;
	}

	return 0;
}

sub send_Tone {
	my $self = shift;
	my $tone = shift;

	if( $self->{calls}->{outgoing} ) {
		$self->_get_Interface( "VoiceCallManager" )->SendTones( $tone );
		return 1;
	}
	return 0;
}

sub new( $$ ) {
	my( $class, $arg ) = @_;
	my $self = bless{ options => $arg } => $class;
	
	$self->{bus} = Net::DBus->system;
	$self->{ofono} = $self->{bus}->get_service( "org.ofono" );

	if( $self->{ofono} ) {
		$self->{manager} = $self->_get_Interface( "Manager", "/" );

		if( $self->get_modems() ) {

			$self->{status} = {};
			$self->_get_NetworkRegistration();

			$self->{calls} = {};
			$self->{calls}->{outgoing} = 0;
			$self->{calls}->{path} = 0;

			return $self;
		}
	}
	die( "Could not connect to org.ofono via DBus!\n" );
}

1;
