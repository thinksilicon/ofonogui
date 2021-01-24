#!/usr/bin/perl

use strict;
use warnings;

use lib qw( lib );
use OfonoGUI::GUI;

my $gui = OfonoGUI::GUI->new();
$gui->run;
#$gui->main_window();

