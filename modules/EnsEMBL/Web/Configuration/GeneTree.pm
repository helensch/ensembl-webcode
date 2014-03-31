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

package EnsEMBL::Web::Configuration::GeneTree;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'Image';
}

sub caption { 
  my $self = shift;
  my $gt = $self->hub->param('gt');
  return "Gene Tree $gt"; 
}

sub availability {
  my $self = shift;
  return $self->default_availability;
}

sub populate_tree {
  my $self = shift;
  $self->create_node('Image', 'Gene Tree Image', [qw(image EnsEMBL::Web::Component::GeneTree::ComparaTree)]);
}

sub modify_page_elements { $_[0]->page->remove_body_element('summary'); }

1;
