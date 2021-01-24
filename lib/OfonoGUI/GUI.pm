package OfonoGUI::GUI;

use strict;
use warnings;
use diagnostics;
use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK );

require Exporter;
@ISA = qw( Exporter );
@EXPORT =qw(
	main_window
	status
);

our $VERSION = '0.1';

use feature ':5.14';
use Glib qw/TRUE FALSE/;
use Glib::IO;
use Gtk3 '-init';


use Number::Phone;
#use OfonoGUI::Bluez;
use OfonoGUI::DBus;

use Data::Dumper;

use constant NOT_CONNECTED => 0;
use constant CONNECTED => 1;
use constant DIALING => 2;
use constant CALL_ACTIVE => 4;
use constant CALL_ENDED => 8;
use constant CALL_INCOMING => 16;

sub _main_window {
	my $self = shift;

# ==== Window Grid: 1 column, 3 rows ====
	my $grid = Gtk3::Grid->new;
#	$grid->set_row_homogeneous( TRUE );
	$grid->set_column_homogeneous( TRUE );
	$self->{window}->add( $grid );

# ==== Dial Frame ====
	my $frame_dial = Gtk3::AspectFrame->new(
		0.5,	# xalign
		0.5,	# yalign
		1,	# ratio
		TRUE	# obey_child
	);
	$frame_dial->set_label( "Dialpad" );
	$grid->attach( $frame_dial, 0, 0, 1, 1 );

	my $grid_dial = Gtk3::Grid->new;
	$grid_dial->set_row_spacing( 10 );
	$grid_dial->set_column_spacing( 10 );
	$grid_dial->set_row_homogeneous( TRUE );
	$grid_dial->set_column_homogeneous( TRUE );
	$grid_dial->set_border_width( 10 );
	$frame_dial->add( $grid_dial );

	my @buttons;
	for( my $i = 1; $i <= 9; $i++ ) {
		push @buttons, Gtk3::Button->new_with_label( $i );

		$buttons[-1]->signal_connect( clicked => sub{
			my $this = shift;
			$self->_numpad( $this->get_label() );
		} );
	}
	foreach my $char ( '*', '0', '#' ) {
		push @buttons, Gtk3::Button->new_with_label( $char );

                $buttons[-1]->signal_connect( clicked => sub{
                        my $this = shift;
                        $self->_numpad( $this->get_label() );
                } );
	}

	for( my $i = 0; $i < 4; $i++ ) {
		for( my $j = 0; $j < 3; $j++ ) {
			$grid_dial->attach( $buttons[ ( $i + 2 * $i ) + $j ], $j * 3, $i, 3, 1 );
		}
	}

# ==== Input Frame ====
	my $frame_input = Gtk3::Frame->new(
		0.5,
		0
	);
	$frame_input->set_label( "Number" );
	$grid->attach( $frame_input, 0, 1, 1, 1 );

	my $grid_input = Gtk3::Grid->new;
	$grid_input->set_column_spacing( 10 );
	$grid_input->set_border_width( 10 );
	$frame_input->add( $grid_input );


	$grid_input->attach( $self->{input_number}, 0, 0, 1, 1 );

#        my $callbutton = Gtk3::Button->new();
#        my $icon = Glib::IO::ThemedIcon->new( "call-start" );
#        my $image = Gtk3::Image->new_from_gicon( $icon, 5 );
#        $callbutton->add( $image );
#	$callbutton->signal_connect( clicked => sub{ $self->_callbutton() } );

	my $clearbutton = Gtk3::Button->new();
	my $icon_clear = Glib::IO::ThemedIcon->new( "edit-clear" );
	my $image_clear = Gtk3::Image->new_from_gicon( $icon_clear, 5 );
	$clearbutton->add( $image_clear );
	$clearbutton->signal_connect( clicked => sub {
		$self->{input_number}->set_text( "" );
	} );

	$grid_input->attach( $clearbutton, 1, 0, 1, 1 );
#	$grid_input->attach( $callbutton, 2, 0, 1, 1 );
	$grid_input->attach( $self->{callbutton}->{window}, 2, 0, 1, 1 );

# ==== Status Frame ====
	my $frame_status = Gtk3::Frame->new(
		0.5,
		0
	);
	$frame_status->set_label( "Phone Status" );
	$grid->attach( $frame_status, 0, 2, 1, 1 );

	my $grid_status = Gtk3::Grid->new;
	$grid_status->set_column_spacing( 10 );
	$grid_status->set_border_width( 10 );
	$frame_status->add( $grid_status );

	my $icon_phone = Glib::IO::ThemedIcon->new( "phone" );
	my $image_phone = Gtk3::Image->new_from_gicon( $icon_phone, 5 );
	$grid_status->attach( $image_phone, 0, 0, 1, 1 );

	$grid_status->attach( $self->{status_label}, 1, 0, 1, 1 );

}

sub _callbutton {
	my $self = shift;

	if( $self->{call}->{status} == CONNECTED || $self->{call}->{status} == CALL_ENDED ) {
		my $number = $self->{input_number}->get_text();
		$number =~ s/\s*//g;

		if( $number ) {
			my $np = Number::Phone->new( $number );

			if( $np && $np->is_valid() ) {
				$self->{call}->{status} = DIALING;
				$self->{call}->{number} = $number;
				$self->{call}->{duration} = time;

				# tell the modem to call the number
				$self->{dbus}->number_Call( $number );
			}
		}

		$self->{input_number}->set_text( "" );
	} elsif( $self->{call}->{status} == DIALING || $self->{call}->{status} == CALL_ACTIVE ) {
		# tell the modem to hang up
		$self->{dbus}->hangup_Call();


		$self->{call}->{status} = CALL_ENDED;

	} elsif( $self->{call}->{status} == CALL_INCOMING ) {
		$self->{call}->{duration} = time;
		$self->{dbus}->answer_Call();
	}

	$self->status();
}

sub _numpad {
	my $self = shift;
	my $number = shift;

	if( $self->{call}->{status} == CALL_ACTIVE ) {
		# We wanna send dial tones here
		$self->{dbus}->send_Tone( $number );

	} elsif( $self->{call}->{status} == CONNECTED || $self->{call}->{status} == CALL_ENDED ) {
		my $phone_number = $self->{input_number}->get_text();
		$self->{input_number}->set_text( $phone_number . $number );
	}
}

sub status {
	my $self = shift;

	# first query DBus what the modem is doing
	my $s = $self->{dbus}->get_status();
	if( $s->{Status} eq 'registered' ) {
		if( $self->{call}->{status} < CONNECTED ) {
			$self->{call}->{status} = CONNECTED;

			my $modem_info = $self->{dbus}->get_modem_info();
			$self->{status_label}->set_text( "Connected to ".$modem_info->{Name} );
		} else {
			if( $self->{call}->{status} == DIALING ) {
				$self->{status_label}->set_text( "Calling ".$self->{call}->{number}." ..." );
				$self->{callbutton}->{bar}->set_image( $self->{stop_callimage}->{bar} );
				$self->{callbutton}->{window}->set_image( $self->{stop_callimage}->{window} );

				$self->{dbus}->get_Calls();
				my $call = $self->{dbus}->get_activeCalls();

				if( defined( $call->{State} ) && $call->{State} eq 'active' ) {
					$self->{call}->{status} = CALL_ACTIVE;
				}
			} elsif( $self->{call}->{status} == CALL_ACTIVE ) {
				$self->{status_label}->set_text( "Call active: ".$self->{call}->{number}. " Time ".( time - $self->{call}->{duration} )."s" );

				if( $self->{dbus}->get_Calls() == 0 ) {
					$self->{call}->{status} = CALL_ENDED;
				}
			
			} elsif( $self->{call}->{status} == CALL_ENDED ) {
				$self->{status_label}->set_text( "Call ended. Time ".( time - $self->{call}->{duration} )."s ..." );
				$self->{callbutton}->{bar}->set_image( $self->{start_callimage}->{bar} );
				$self->{callbutton}->{window}->set_image( $self->{start_callimage}->{window} );

				$self->{call}->{status} = CONNECTED;
			} else {
				# listen for incoming calls
				if( $self->{dbus}->get_Calls() ) {
					my $call = $self->{dbus}->get_activeCalls();

					if( $call->{State} eq 'active' ) {
						$self->{callbutton}->{bar}->set_image( $self->{stop_callimage}->{bar} );
						$self->{callbutton}->{window}->set_image( $self->{stop_callimage}->{window} );
						$self->{call}->{status} = CALL_ACTIVE;
					}

					if( $call->{State} eq 'incoming' && $self->{call}->{status} == CONNECTED ) {
						$self->{call}->{status} = CALL_INCOMING;
						

						$self->{status_label}->set_text( "Incoming call from ".$call->{LineIdentification} );
						$self->{call}->{number} = $call->{LineIdentification};
					}
				} else {
					my $call = $self->{dbus}->get_activeCalls();
					if( $self->{call}->{status} == CALL_INCOMING ) {
						$self->{status_label}->set_text( "Missed call from ".$self->{call}->{number} );
						$self->{callbutton}->{bar}->set_image( $self->{missed_callimage}->{bar} );
						$self->{callbutton}->{window}->set_image( $self->{missed_callimage}->{window} );
						
						$self->{call}->{status} == CONNECTED;
					}
				}
			}
		}
	} else {
		$self->{call}->{status} = NOT_CONNECTED;
		$self->{status_label}->set_text( "Not connected." );
	}
}

sub _header {
	my $self = shift;

	my $bar = Gtk3::HeaderBar->new();
	$bar->set_show_close_button( TRUE );
	$bar->set_title( "OfonoGUI" );
	$self->{window}->set_titlebar( $bar );

	my $callbutton = Gtk3::Button->new();

#	my $icon = Glib::IO::ThemedIcon->new( "call-start" );
#	my $image = Gtk3::Image->new_from_gicon( $icon, 5 );
#	$callbutton->add( $image );
#	$callbutton->signal_connect( clicked => sub{ $self->_callbutton() } );

#	$bar->pack_end( $callbutton );
	$bar->pack_end( $self->{callbutton}->{bar} );
}

sub quit {
	my $self = shift;
	my $reason = shift;

	Gtk3->main_quit();
	exit( 0 );
}

sub _init {
	my $self = shift;

	$self->{dbus} = OfonoGUI::DBus->new();

	# Call status
	$self->{call} = {};
	$self->{call}->{status} = NOT_CONNECTED;
	$self->{call}->{oldstatus} = -1;

	my $timer = Glib::Timeout->add( 1000, sub {
		$self->status;
#		print "Tick\n";
		return 1;
	} );

	return 1;
}

sub _build_ui {
	my $self = shift;

	$self->{window} = Gtk3::ApplicationWindow->new( $self->{app} );
	$self->{window}->signal_connect( delete_event => sub { $self->quit() } );
	$self->{window}->set_title( "OfonoGUI" );
	$self->{window}->set_border_width( 10 );

	$self->{input_number} = Gtk3::Entry->new;
	$self->{status_label} = Gtk3::Label->new;

	# create a button each for the top bar and the window
	$self->{start_callicon}->{bar} = Glib::IO::ThemedIcon->new( "call-start" );
	$self->{stop_callicon}->{bar} = Glib::IO::ThemedIcon->new( "call-stop" );
	$self->{missed_callicon}->{bar} = Glib::IO::ThemedIcon->new( "call-missed" );

	$self->{start_callicon}->{window} = Glib::IO::ThemedIcon->new( "call-start" );
	$self->{stop_callicon}->{window} = Glib::IO::ThemedIcon->new( "call-stop" );
	$self->{missed_callicon}->{window} = Glib::IO::ThemedIcon->new( "call-missed" );


	$self->{start_callimage}->{bar} = Gtk3::Image->new_from_gicon( $self->{start_callicon}->{bar}, 5 );
	$self->{stop_callimage}->{bar} = Gtk3::Image->new_from_gicon( $self->{stop_callicon}->{bar}, 5 );
	$self->{missed_callimage}->{bar} = Gtk3::Image->new_from_gicon( $self->{missed_callicon}->{bar}, 5 );
	$self->{start_callimage}->{window} = Gtk3::Image->new_from_gicon( $self->{start_callicon}->{window}, 5 );
	$self->{stop_callimage}->{window} = Gtk3::Image->new_from_gicon( $self->{stop_callicon}->{window}, 5 );
	$self->{missed_callimage}->{window} = Gtk3::Image->new_from_gicon( $self->{missed_callicon}->{window}, 5 );

	$self->{callbutton}->{bar} = Gtk3::Button->new;
	$self->{callbutton}->{bar}->add( $self->{start_callimage}->{bar} );
	$self->{callbutton}->{bar}->signal_connect( clicked => sub{ $self->_callbutton() } );

	$self->{callbutton}->{window} = Gtk3::Button->new;
	$self->{callbutton}->{window}->add( $self->{start_callimage}->{window} );
	$self->{callbutton}->{window}->signal_connect( clicked => sub{ $self->_callbutton() } );

	$self->_header();
	$self->_main_window();

	$self->{window}->show_all;

	return 1;
#	Gtk3->main;
}

sub new( $$ ) {
	my( $class, $arg ) = @_;
	my $self = bless{ options => $arg } => $class;

	$self->{app} = Gtk3::Application->new( 'app.ofonogui', 'flags-none' ); 
	$self->{app}->signal_connect( 'startup'  => sub { $self->_init; } );
	$self->{app}->signal_connect( 'activate' => sub { $self->_build_ui; } );
	$self->{app}->signal_connect( 'shutdown' => sub { $self->quit; } );

	return $self;
}

sub run {
	my $self = shift;
	$self->{app}->run(\@ARGV);
}

1;
