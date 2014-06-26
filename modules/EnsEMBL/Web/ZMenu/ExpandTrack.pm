=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ZMenu::ExpandTrack;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $track   = $hub->param('track');
  my $count   = $hub->param('count');
  my $default = $hub->param('default');
  my $action  = $hub->param('goto');
  
  $self->caption('Expand track depth to:');
  
  $self->add_entry({
    label_html => "Default ($default)",
    link       => $hub->url({ action => $action, $track => '' })
  });
  if ($count > 20) {
    $self->add_entry({
      label_html => '20 features',
      link       => $hub->url({ action => $action, $track => '20' })
    });
  }
  if ($count > 100) {
    $self->add_entry({
      action     => 'View',
      label_html => '100 features',
      link       => $hub->url({ action => $action, $track => '100' })
    });
  }
  $self->add_entry({
    label_html => "All features ($count)",
    link       => $hub->url({ action => $action, $track => $count })
  });
}

1;
