package EnsEMBL::Web::Controller::Command::Filter::InvitationExists;

use strict;
use warnings;

use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Controller::Command::Filter);

### Checks if a given invitation code matches the value stored in the database

{

sub allow {
  my $self = shift;
  my $cgi = $self->action->cgi;
  my $invitation = EnsEMBL::Web::Data::Record::Invite::Group->new($cgi->param('id'));
  if ($invitation) {
    return 1;
  } else {
    return 0;
  }
}

sub message {
  my $self = shift;
  return 'Sorry, this invitation no longer exists in our database. Either it has been deleted by the group administrator, or you have already accepted the invitation (in which case, if you log in, you should see the group in your account panel.';
}

}

1;
