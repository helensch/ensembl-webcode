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

package EnsEMBL::Web::Component::Gene::Family;

### Displays a list of protein families for this gene

use strict;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self           = shift;
  my $hub            = $self->hub;
  my $cdb            = shift || $hub->param('cdb') || 'compara';
  my $object         = $self->object;
  my $sp             = $hub->species_defs->DISPLAY_NAME || $hub->species_defs->species_label($object->species);
  my $families       = $object->get_all_families($cdb);
  my $gene_stable_id = $object->stable_id;

  my $ckey = $cdb eq 'compara_pan_ensembl' ? '_pan_compara' : '';

  my $table = $self->new_table([], [], { data_table => 1, sorting => [ 'id asc' ] });

  $table->add_columns(
    { key => 'id',          title => 'Family ID',                            width => '20%', align => 'left', sort => 'html'   },
    { key => 'annot',       title => 'Consensus annotation',                 width => '30%', align => 'left', sort => 'string' },
    { key => 'transcripts', title => "Other $sp transcripts in this family", width => '30%', align => 'left', sort => 'html'   },
    { key => 'jalview',     title => 'Multiple alignments',                  width => '20%', align => 'left', sort => 'none'   }
  );
  
  foreach my $family_id (sort keys %$families) {
    my $family     = $families->{$family_id};
    my $row        = { id => "$family_id<br /><br />" };
    my $genes      = $families->{$family_id}{'info'}{'genes'};
    my $url_params = { function => "Genes$ckey", family => $family_id, g => $gene_stable_id, cdb => $cdb };
    
    $row->{'id'}          .= scalar @$genes > 1 ? sprintf('(<a href="%s">%s genes</a>)', $hub->url($url_params), scalar @$genes) : '(1 gene)';
    $row->{'id'}          .= sprintf '<br />(<a href="%s">all proteins in family</a>)',  $hub->url({ function => "Proteins$ckey", family => $family_id });
    $row->{'annot'}        = $families->{$family_id}{'info'}{'description'};
    $row->{'transcripts'}  = '<ul class="compact">';
    $row->{'transcripts'} .= sprintf '<li><a href="%s">%s</a> (%s)</li>', $hub->url($url_params), $_->stable_id, $_->display_xref for @{$family->{'transcripts'}}; 
    $row->{'transcripts'} .= '</ul>';

    my $fam_obj         = $object->create_family($family_id, $cdb);
    my $ensembl_members = $fam_obj->get_Member_by_source('ENSEMBLPEP');
    
    my @all_pep_members;
    push @all_pep_members, @$ensembl_members;
    push @all_pep_members, @{$fam_obj->get_Member_by_source('Uniprot/SPTREMBL')};
    push @all_pep_members, @{$fam_obj->get_Member_by_source('Uniprot/SWISSPROT')};

    $row->{'jalview'} = $self->jalview_link($family_id, 'Ensembl', $ensembl_members, $cdb) . $self->jalview_link($family_id, '', \@all_pep_members, $cdb) || 'No alignment has been produced for this family.';

    $table->add_row($row);
  }
  
  return $table->render;
}

sub jalview_link {
  my ($self, $family, $type, $refs, $cdb) = @_;
  my $count = @$refs;
  (my $ckey = $cdb) =~ s/compara//;
  my $url   = $self->hub->url({ function => "Alignments$ckey", family => $family });
  
  return qq{<p class="space-below">$count $type members of this family <a href="$url">JalView</a></p>};
}

1;
