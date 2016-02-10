=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet_transcript_new;

### Parent module for various glyphsets that draw transcripts
### (styles include exons as blocks, joined by angled lines across introns)

use strict;

use List::Util qw(min max);
use List::MoreUtils qw(natatime);

use base qw(EnsEMBL::Draw::GlyphSet_transcript_new_base);

sub features { return []; }

## Let us define all the renderers here...
## ... these are just all wrappers - the parameter is 1 to draw labels
## ... 0 otherwise...

sub render_normal                  { $_[0]->render_transcripts(1);           }
sub render_transcript              { $_[0]->render_transcripts(1);           }
sub render_transcript_label        { $_[0]->render_transcripts(1);           }
sub render_transcript_label_coding { $_[0]->render_transcripts(1);           }
sub render_transcript_gencode_basic{ $_[0]->render_transcripts(1);           }
sub render_transcript_nolabel      { $_[0]->render_transcripts(0);           }
sub render_collapsed_label         { $_[0]->render_collapsed(1);             }
sub render_collapsed_nolabel       { $_[0]->render_collapsed(0);             }
sub render_gene_label              { $_[0]->render_genes(1);                 }
sub render_gene_nolabel            { $_[0]->render_genes(0);                 }
sub render_as_transcript_label     { $_[0]->render_alignslice_transcript(1); }
sub render_as_transcript_nolabel   { $_[0]->render_alignslice_transcript(0); }
sub render_as_collapsed_label      { $_[0]->render_alignslice_collapsed(1);  }
sub render_as_collapsed_nolabel    { $_[0]->render_alignslice_collapsed(0);  }

sub calculate_collapsed_joins {
  my ($self,$gene_stable_id) = @_;
 
  my $hub = $self->{'config'}->hub;
  my $ga = $hub->get_adaptor('get_GeneAdaptor',
                             $self->my_config('db'),$self->species);
  my $gene = $ga->fetch_by_stable_id($gene_stable_id);
 
  my $previous_species = $self->my_config('previous_species');
  my $next_species     = $self->my_config('next_species');
  my $previous_target  = $self->my_config('previous_target');
  my $next_target      = $self->my_config('next_target');
  my $join_types       = $self->get_parameter('join_types');
  my $alt_alleles     = $gene->get_all_alt_alleles;
  my $seq_region_name = $gene->slice->seq_region_name;
  my ($target, @gene_tags);
  
  my @joins;

  if ($previous_species) {
    for ($self->get_gene_joins($gene, $previous_species, $join_types)) {
      $target = $previous_target ? ":$seq_region_name:$previous_target" : '';
      push @joins,{
        key => "$gene_stable_id:$_->[0]$target",
        colour => $_->[1],
        legend => $_->[2]
      };          
    }
    
    push @gene_tags, map { join '=', $_->stable_id, $gene_stable_id } @{$self->filter_by_target($alt_alleles, $previous_target)};
  }

  if ($next_species) {
    for ($self->get_gene_joins($gene, $next_species, $join_types)) {
      $target = $next_target ? ":$next_target:$seq_region_name" : '';
      push @joins,{
        key => "$_->[0]:$gene_stable_id$target",
        colour => $_->[1],
        legend => $_->[2]
      };
    }
    
    push @gene_tags, map { join '=', $gene_stable_id, $_->stable_id } @{$self->filter_by_target($alt_alleles, $next_target)};
  }
  my $alt_alleles_col  = $self->my_colour('alt_alleles_join');
  for (@gene_tags) {
    push @joins,{
      key => $_,
      colour => $alt_alleles_col,
      legend => 'Alternative alleles'
    };
  }
  return \@joins;
}

sub calculate_expanded_joins {
  my ($self,$gene,$gene_stable_id) = @_;

  my $previous_species = $self->my_config('previous_species');
  my $next_species     = $self->my_config('next_species');
  my $previous_target  = $self->my_config('previous_target');
  my $next_target      = $self->my_config('next_target');
  my $join_types       = $self->get_parameter('join_types');
  my $seq_region_name = $gene->slice->seq_region_name;
  my $alt_alleles = $gene->get_all_alt_alleles;
  my $alltrans    = $gene->get_all_Transcripts; # vega stuff to link alt-alleles on longest transcript
  my @s_alltrans  = sort { $a->length <=> $b->length } @$alltrans;
  my $long_trans  = pop @s_alltrans;
  my @transcripts;
  my $alt_alleles_col  = $self->my_colour('alt_alleles_join');
 
  my (@joins,%tjoins); 
  my $tsid = $long_trans->stable_id;
  
  foreach my $gene (@$alt_alleles) {
    my $vtranscripts = $gene->get_all_Transcripts;
    my @sorted_trans = sort { $a->length <=> $b->length } @$vtranscripts;
    push @transcripts, (pop @sorted_trans);
  }
  
  if ($previous_species) {
    my ($peptide_id, $homologues, $homologue_genes) = $self->get_gene_joins($gene, $previous_species, $join_types, 'ENSEMBLGENE');
    
    if ($peptide_id) {
      foreach my $h (@$homologues) {
        push @{$tjoins{$peptide_id}},{
          key => "$h->[0]:$peptide_id",
          colour => $h->[1],
          legend => $h->[2],
        };
      }
      foreach my $h (@$homologue_genes) {
        push @{$tjoins{$peptide_id}},{
          key => "$gene_stable_id:$h->[0]",
          colour => $h->[1],
          legend => $h->[2],
        };
      }
    }
  
    my $alts = $self->filter_by_target(\@transcripts,$previous_target); 
    foreach my $t (@$alts) {
      push @joins,{
        key => join('=',$t->stable_id,$tsid),
        colour => $alt_alleles_col,
        legend => 'Alternative alleles'
      };
    }
  }
  
  if ($next_species) {
    my ($peptide_id, $homologues, $homologue_genes) = $self->get_gene_joins($gene, $next_species, $join_types, 'ENSEMBLGENE');
    
    if ($peptide_id) {
      foreach my $h (@$homologues) {
        push @{$tjoins{$peptide_id}},{
          key => "$peptide_id:$h->[0]",
          colour => $h->[1],
        };
      }
      foreach my $h (@$homologue_genes) {
        push @{$tjoins{$peptide_id}},{
          key => "$h->[0]:$gene_stable_id",
          colour => $h->[1],
        };
      }
    }
   
    my $alts = $self->filter_by_target(\@transcripts,$next_target);
    foreach my $t (@$alts) {
      push @joins,{
        key => join('=',$t->stable_id,$tsid),
        colour => $alt_alleles_col,
        legend => 'Alternative alleles'
      };
    }
  }
  $tjoins{$tsid} = \@joins;
  return \%tjoins;
}
  
sub render_collapsed {
  my ($self, $labels) = @_;

  return $self->render_text('transcript', 'collapsed') if $self->{'text_export'};
  
  my $config           = $self->{'config'};
  my $container        = $self->{'container'}{'ref'} || $self->{'container'};
  my $length           = $container->length;
  my $strand           = $self->strand;
  my $selected_db      = $self->core('db');
  my $selected_gene    = $self->my_config('g') || $self->core('g');
  my $db               = $self->my_config('db');
  my $show_labels      = $self->my_config('show_labels');
  my $link             = $self->get_parameter('compara') ? $self->my_config('join') : 0;
  my $alt_alleles_col  = $self->my_colour('alt_alleles_join');
  my $y                = 0;
  my $h                = 8;
  my %used_colours;
  
  my ($genes, $highlights, $transcripts, $exons) = $self->features;
 
  my @ggdraw;
  foreach my $gene (@$genes) {
    my (@edraw);
    my $gene_stable_id = $gene->stable_id;
    
    my @exons      = map { $_->start > $length || $_->end < 1 ? () : $_ } @{$exons->{$gene_stable_id}}; # Get all the exons which overlap the region for this gene
    my $colour_key = $self->colour_key($gene);
    my $colour     = $self->my_colour($colour_key);
    
    foreach my $exon (@exons) {
      push @edraw,{ start => $exon->start, end => $exon->end };
    }

    my $joins = []; 
    if ($link and $gene_stable_id) {
      $joins = $self->calculate_collapsed_joins($gene_stable_id);
    }
    push @ggdraw,{
      start => $gene->start,
      end => $gene->end,
      title => $self->gene_title($gene),
      href => $self->href($gene),
      label => $self->feature_label($gene),
      highlight => $highlights->{$gene_stable_id},
      colour_key => $self->colour_key($gene),
      exons => \@edraw,
      joins => $joins,
      strand => $gene->strand,
    };   
  }
  my $draw_labels = ($labels and $show_labels ne 'off');
  $self->mr_bump(\@ggdraw,$draw_labels,$length);
  $self->draw_collapsed_genes($length,$draw_labels,$strand,\@ggdraw);

  if($config->get_option('opt_empty_tracks') != 0 && !@$genes) {
    $self->no_track_on_strand;
  }
}

sub render_transcripts {
  my ($self, $labels) = @_;

  return $self->render_text('transcript') if $self->{'text_export'};
  
  my $config            = $self->{'config'};
  my $container         = $self->{'container'}{'ref'} || $self->{'container'};
  my $length            = $container->length;
  my $strand            = $self->strand;
  my $show_labels       = $self->my_config('show_labels');
  my $link              = $self->get_parameter('compara') ? $self->my_config('join') : 0;
  my $target            = $self->get_parameter('single_Transcript');
  my $target_gene       = $self->get_parameter('single_Gene');
  my %used_colours;
  
  my ($genes, $highlights, $transcripts, $exons) = $self->features;
  
  my @tdraw;
  foreach my $gene (@$genes) {
    my $gene_stable_id = $gene->can('stable_id') ? $gene->stable_id : undef;
    next if $target_gene && $gene_stable_id ne $target_gene;
    
    my $tjoins;
    if ($link && $gene_stable_id) {
      $tjoins = $self->calculate_expanded_joins($gene,$gene_stable_id);
    }

    my $gene_strand = $gene->strand; 
    my @sorted_transcripts = map $_->[1], sort { $b->[0] <=> $a->[0] } map [ $_->start * $gene_strand, $_ ], @{$transcripts->{$gene_stable_id}};
   
    foreach my $transcript (@sorted_transcripts) {
      my $transcript_stable_id = $transcript->stable_id;
      
      next if $transcript->start > $length || $transcript->end < 1;
      next if $target && $transcript_stable_id ne $target; # For exon_structure diagram only given transcript
      next unless $exons->{$transcript_stable_id};          # Skip if no exons for this transcript
     
      my @ids = ($transcript->stable_id);
      push @ids,$transcript->translation->stable_id if $transcript->translation;
      my @joins = @{$tjoins->{$transcript->stable_id}||[]};
      if($transcript->translation) {
        push @joins,@{$tjoins->{$transcript->translation->stable_id}||[]};
      }

      my $td = {
        joins => \@joins,
        title  => $self->title($transcript, $gene),
        href   => $self->href($gene, $transcript),
        colour_key => $self->colour_key($gene, $transcript),
        start => max(0,$transcript->start),
        end => min($length,$transcript->end),
        label => $self->feature_label($gene,$transcript),
        exons => [],
        strand => $gene->strand,
      };
      $td->{'colour'} = $self->my_colour($td->{'colour_key'});
      $td->{'highlight'} = $highlights->{$transcript_stable_id} if $config->get_option('opt_highlight_feature') != 0 && $highlights->{$transcript_stable_id} && !defined $target;
  
      my @exons = @{$exons->{$transcript_stable_id}};
      
      next if $exons[0][0]->strand != $gene_strand && $self->{'do_not_strand'} != 1; # If stranded diagram skip if on wrong strand
    
      for(my $i=0;$i<@exons;$i++) {
        next unless defined $exons[$i][0]; # genscan weirdness
        my $target = {
          start => $exons[$i][0]->start,
          end => $exons[$i][0]->end,
        };
        if($i and $exons[$i][0]->dbID eq $exons[$i-1][0]->dbID) {
          $target = $td->{'exons'}[$i-1];
        } else {
          push @{$td->{'exons'}},$target;
        }
        if($exons[$i][1] eq 'fill') {
          $target->{'coding_start'} = $exons[$i][2];
          $target->{'coding_end'} = $exons[$i][3];
        }
      }
      push @tdraw,$td; 
    }
  }
  my $draw_labels = ($labels and $show_labels ne 'off');
  $self->mr_bump(\@tdraw,$draw_labels,$length);
  $self->draw_expanded_transcripts(\@tdraw,$length,$strand,$draw_labels);
  if($config->get_option('opt_empty_tracks') != 0 && !@$genes) {
    $self->no_track_on_strand;
  }
}

sub render_alignslice_transcript {
  my ($self, $labels) = @_;

  return $self->render_text('transcript') if $self->{'text_export'};

  my $config            = $self->{'config'};
  my $container         = $self->{'container'}{'ref'} || $self->{'container'};
  my $length            = $container->length;
  my $selected_db       = $self->core('db');
  my $strand            = $self->strand;
  my $show_labels       = $self->my_config('show_labels');
  my $target            = $self->get_parameter('single_Transcript');
  my $target_gene       = $self->get_parameter('single_Gene');
  
  my ($genes, $highlights, $transcripts) = $self->features;

  my @tdraw;
  foreach my $gene (@$genes) {
    my $gene_strand    = $gene->strand;
    my $gene_stable_id = $gene->can('stable_id') ? $gene->stable_id : undef;
    
    next if $target_gene && $gene_stable_id ne $target_gene;
    
    my @sorted_transcripts = map $_->[1], sort { $b->[0] <=> $a->[0] } map [ $_->start * $gene_strand, $_ ], @{$transcripts->{$gene_stable_id}};
    
    foreach my $transcript (@sorted_transcripts) {
      next if $transcript->start > $length || $transcript->end < 1;
      next if $target && $transcript->stable_id ne $target;
      
      my @raw_exons = $self->map_AlignSlice_Exons($transcript, $length);
      
      next if scalar @raw_exons == 0;
      
      my $transcript_stable_id = $transcript->stable_id;
      my $td = {
        colour_key => $self->colour_key($gene, $transcript),
        title  => $self->title($transcript, $gene),
        href   => $self->href($gene, $transcript),
        highlight => $highlights->{$transcript_stable_id},
        label => $self->feature_label($gene,$transcript),
        start => $transcript->start,
        end => $transcript->end,
        strand => $transcript->strand,
        exons => [],
        joins => [],
      };
      
      my $colour_key = $self->colour_key($gene, $transcript);    
      my $colour     = $self->my_colour($colour_key);
      my $label      = $self->my_colour($colour_key, 'text');

      my $coding_start = defined $transcript->coding_region_start ? $transcript->coding_region_start :  -1e6;
      my $coding_end   = defined $transcript->coding_region_end   ? $transcript->coding_region_end   :  -1e6;

      for(my $i=0;$i<@raw_exons;$i++) {
        my $e = $raw_exons[$i];
        my $e_coding_start = max($coding_start,$e->start);
        my $e_coding_end = min($coding_end,$e->end);
        my $exon = {
          start => $e->start,
          end => $e->end,
          strand => $e->strand,
        };
        if($e->{'exon'}->{'etype'} eq 'M') {
          $exon->{'missing'} = 1;
        } else {
          if($e->start < $e_coding_start || $e->end > $e_coding_end) {
          }
          if($e_coding_start <= $e_coding_end) {
            $exon->{'coding_start'} = $e_coding_start-$e->start;
            $exon->{'coding_end'} = $e->end-$e_coding_end;
          }
        }
        push @{$td->{'exons'}},$exon;
      }
      $td->{'colour'} = $self->my_colour($td->{'colour_key'});
      push @tdraw,$td;
    }
  }
  my $draw_labels = ($labels and $show_labels ne 'off');
  $self->mr_bump(\@tdraw,$draw_labels,$length);
  $self->draw_expanded_transcripts(\@tdraw,$length,$strand,$draw_labels,$target);
  if($config->get_option('opt_empty_tracks') != 0 && !@$genes) {
    $self->no_track_on_strand;
  }
}

sub render_alignslice_collapsed {
  my ($self, $labels) = @_;
  
  return $self->render_text('transcript') if $self->{'text_export'};

  my $config            = $self->{'config'};
  my $container         = $self->{'container'}{'ref'} || $self->{'container'};
  my $length            = $container->length;
  my $selected_db       = $self->core('db');
  my $selected_gene     = $self->core('g');
  my $pix_per_bp        = $self->scalex;
  my $strand            = $self->strand;
  my $strand_flag       = $self->my_config('strand');
  my $db                = $self->my_config('db');
  my $show_labels       = $self->my_config('show_labels');
  my $y                 = 0;
  my $h                 = 8;
  
  my ($genes, $highlights) = $self->features;
 
  my @ggdraw; 
  foreach my $gene (@$genes) {
    my $gene_strand    = $gene->strand;
    my $gene_stable_id = $gene->stable_id;
    
    my $colour_key = $self->colour_key($gene);    
    my $label      = $self->my_colour($colour_key, 'text');
    
    my @exons;
    
    # In compact mode we 'collapse' exons showing just the gene structure, i.e overlapping exons/transcripts will be merged
    foreach my $transcript (@{$gene->get_all_Transcripts}) {
      next if $transcript->start > $length || $transcript->end < 1;
      push @exons, $self->map_AlignSlice_Exons($transcript, $length);
    }
    
    next unless @exons;
    
    # All exons in the gene will be connected by a simple line which starts from a first exon if it within the viewed region, otherwise from the first pixel. 
    # The line ends with last exon of the gene or the end of the image
    my $start = $exons[0]->{'exon'}->{'etype'} eq 'B' ? 1 : 0;       # Start line from 1 if there are preceeding exons    
    my $end  = $exons[-1]->{'exon'}->{'etype'} eq 'A' ? $length : 0; # End line at the end of the image if there are further exons beyond the region end
    
    # Get only exons in view
    my @exons_in_view = sort { $a->start <=> $b->start } grep { $_->{'exon'}->{'etype'} =~ /[NM]/} @exons;
    
    # Set start and end of the connecting line if they are not set yet
    $start ||= $exons_in_view[0]->start;
    $end   ||= $exons_in_view[-1]->end;
    
    # Draw exons
    my @edraw;
    foreach my $exon (@exons_in_view) {
      push @edraw,{ start => $exon->start, end => $exon->end };
    }

    push @ggdraw,{
      start => $start,
      end => $end,
      title  => $self->gene_title($gene),
      href   => $self->href($gene),
      colour_key => $colour_key,
      exons => \@edraw,
      label => $self->feature_label($gene),
      strand => $gene->strand,
    };
  }
  my $draw_labels = ($labels && $show_labels ne 'off');
  $self->mr_bump(\@ggdraw,$draw_labels,$length);
  $self->draw_collapsed_genes($length,$draw_labels,$strand,\@ggdraw);

  if($config->get_option('opt_empty_tracks') != 0 && !@$genes) {
    $self->no_track_on_strand;
  }
}

sub render_genes {
  my $self = shift;

  return $self->render_text('gene') if $self->{'text_export'};
  
  my $config           = $self->{'config'};
  my $container        = $self->{'container'}{'ref'} || $self->{'container'};
  my $length           = $container->length;
  my $pix_per_bp       = $self->scalex;
  my $strand           = $self->strand;
  my $selected_gene    = $self->my_config('g') || $self->core('g');
  my $label_threshold  = $self->my_config('label_threshold') || 50e3;
  my $navigation       = $self->my_config('navigation') || 'on';
  my $link             = $self->get_parameter('compara') ? $self->my_config('join') : 0;
  my $this_db          = ($self->core('db') eq $self->my_config('db'));
  
  my $hub = $self->{'config'}->hub;
  my $ggdraw = $hub->get_query('GlyphSet::Transcript')->go($self,{
    species => $self->species,
    pattern => $self->my_config('colour_key'),
    shortlabels => $self->get_parameter('opt_shortlabels'),
    label_key => $self->my_config('label_key'),
    slice => $self->{'container'},
    logic_names => $self->my_config('logic_names'),
    db => $self->my_config('db'),
  });
  foreach my $g (@$ggdraw) {
    my $gene_stable_id = $g->{'stable_id'};
    if($this_db and $gene_stable_id eq $selected_gene) {
      $g->{'highlight'} = 'highlight2';
    }
    if($link) {
      $g->{'joins'} = $self->calculate_collapsed_joins($gene_stable_id);
    }
  }

  my $show_navigation = $navigation eq 'on';
  delete $_->{'href'} unless $show_navigation;
 
  my $draw_labels = $self->get_parameter('opt_gene_labels');
  $draw_labels = 1 unless defined $draw_labels;
  $draw_labels = shift if @_;
  $draw_labels = 0 if $label_threshold * 1001 < $length;

  $self->draw_rect_genes($ggdraw,$length,$draw_labels,$strand);

  if($config->get_option('opt_empty_tracks') != 0 && !@$ggdraw) {
    $self->no_track_on_strand;
  }
}

sub render_text {
  my $self = shift;
  my ($feature_type, $collapsed) = @_;
  
  my $container   = $self->{'container'}{'ref'} || $self->{'container'};
  my $length      = $container->length;
  my $strand      = $self->strand;
  my $strand_flag = $self->my_config('strand') || 'b';
  my $target      = $self->get_parameter('single_Transcript');
  my $target_gene = $self->get_parameter('single_Gene');
  my ($genes)     = $self->features;
  my $export;
  
  foreach my $gene (@$genes) {
    my $gene_id = $gene->can('stable_id') ? $gene->stable_id : undef;
    
    next if $target_gene && $gene_id ne $target_gene;
    
    my $gene_type   = $gene->status . '_' . $gene->biotype;
    my $gene_name   = $gene->can('display_xref') && $gene->display_xref ? $gene->display_xref->display_id : undef;
    my $gene_source = $gene->source;
    
    if ($feature_type eq 'gene') {
      $export .= $self->_render_text($gene, 'Gene', { 
        headers => [ 'gene_id', 'gene_name', 'gene_type' ],
        values  => [ $gene_id, $gene_name, $gene_type ]
      });
    } else {
      my $exons = {};
      
      foreach my $transcript (@{$gene->get_all_Transcripts}) {
        next if $transcript->start > $length || $transcript->end < 1;
        
        my $transcript_id = $transcript->stable_id;
        
        next if $target && ($transcript_id ne $target); # For exon_structure diagram only given transcript
        
        my $transcript_name = 
          $transcript->can('display_xref') && $transcript->display_xref ? $transcript->display_xref->display_id : 
          $transcript->can('analysis') && $transcript->analysis ? $transcript->analysis->logic_name : 
          undef;
        
        foreach (sort { $a->start <=> $b->start } @{$transcript->get_all_Exons}) {
          next if $_->start > $length || $_->end < 1;
          
          if ($collapsed) {
            my $stable_id = $_->stable_id;
            
            next if $exons->{$stable_id};
            
            $exons->{$stable_id} = 1;
          }
           
          $export .= $self->export_feature($_, $transcript_id, $transcript_name, $gene_id, $gene_name, $gene_type, $gene_source);
        }
      }
    }
  }
  
  return $export;
}

#============================================================================#
#
# The following three subroutines are designed to get homologous peptide ids
# 
#============================================================================#

# Get homologous gene ids for given gene
sub get_gene_joins {
  my ($self, $gene, $species, $join_types, $source) = @_;
  
  my $config     = $self->{'config'};
  my $compara_db = $config->hub->database('compara');
  return unless $compara_db;
  
  my $ma = $compara_db->get_GeneMemberAdaptor;
  return unless $ma;
  
  my $qy_member = $ma->fetch_by_stable_id($gene->stable_id);
  return unless defined $qy_member;
  
  my $method = $config->get_parameter('force_homologue') || $species eq $config->{'species'} ? $config->get_parameter('homologue') : undef;
  my $func   = $source ? 'get_homologous_peptide_ids_from_gene' : 'get_homologous_gene_ids';
  
  return $self->$func($species, $join_types, $compara_db->get_HomologyAdaptor, $qy_member, $method ? [ $method ] : undef);
}
  
sub get_homologous_gene_ids {
  my ($self, $species, $join_types, $homology_adaptor, $qy_member, $method) = @_;
  my @homologues;
  
  foreach my $homology (@{$homology_adaptor->fetch_all_by_Member($qy_member, -TARGET_SPECIES => [$species], -METHOD_LINK_TYPE => $method)}) {
    my $colour_key = $join_types->{$homology->description};
    
    next if $colour_key eq 'hidden';
    
    my $colour = $self->my_colour($colour_key . '_join');
    my $label  = $self->my_colour($colour_key . '_join', 'text');
    
    my $tg_member = $homology->get_all_Members()->[1];
    push @homologues, [ $tg_member->gene_member->stable_id, $colour, $label ];
  }
  
  return @homologues;
}

# Get homologous protein ids for given gene
sub get_homologous_peptide_ids_from_gene {
  my ($self, $species, $join_types, $homology_adaptor, $qy_member, $method) = @_;
  my ($stable_id, @homologues, @homologue_genes);
  
  foreach my $homology (@{$homology_adaptor->fetch_all_by_Member($qy_member, -TARGET_SPECIES => [$species], -METHOD_LINK_TYPE => $method)}) {
    my $colour_key = $join_types->{$homology->description};
    
    next if $colour_key eq 'hidden';
    
    my $colour = $self->my_colour($colour_key . '_join');
    my $label  = $self->my_colour($colour_key . '_join', 'text');
    
    $stable_id    = $homology->get_all_Members()->[0]->stable_id;
    my $tg_member = $homology->get_all_Members()->[1];
    push @homologues,      [ $tg_member->stable_id,              $colour, $label ];
    push @homologue_genes, [ $tg_member->gene_member->stable_id, $colour         ];
  }
  
  return ($stable_id, \@homologues, \@homologue_genes);
}

sub filter_by_target {
  my ($self, $alt_alleles, $target) = @_;
  
  $alt_alleles = [ grep $_->slice->seq_region_name eq $target, @$alt_alleles ] if $target;
  
  return $alt_alleles;
}

#============================================================================#
#
# Helper functions....
# 
#============================================================================#

sub map_AlignSlice_Exons {
  my ($self, $transcript, $length) = @_;
  
  my @as_exons;
  my @exons;
  my $m_flag = 0; # Indicates that if an exons start is undefined it is missing exon
  my $exon_type = 'B';
  my $fstart = 0; # Start value for B exons
  
  # get_all_Exons returns all exons of AlignSlice including missing exons 
  # (they are located in primary species but not in secondary - we still get them for secondary species but
  #  without coordinates)
  # Here we mark all exons in following way for future display  
  # B - exons that are located in front of viewed region
  # A - exons that are located behind the viewed region
  # N - normal exons
  # M - exons that are between normal exons
  
  # First we preceeding, normal and missing exons (these will include A exons)
  foreach my $ex (@{$transcript->get_all_Exons}) {
    if ($ex->start) {
      $m_flag = 1;
      $exon_type = 'N';
      $fstart = $ex->end;
    } elsif ($m_flag) {
      $exon_type = 'M';
    }
    
    $ex->{'exon'}->{'etype'} = $exon_type;
    $ex->{'exon'}->{'fstart'} = $fstart if $exon_type eq 'M';
    
    push @as_exons, $ex;
  }
  
  # Now mark A exons
  $exon_type = 'A';
  $m_flag = 0; # Reset missing exon flag
  
  $fstart = $length + 2; # Start value for A exons (+2 to get it outside visible area)
  
  foreach my $ex (reverse @as_exons) {
    if ($ex->start) {
      $m_flag = 1;
      $fstart = $ex->start;
    } else {
      if (!$m_flag) {
        $ex->{'exon'}->{'etype'} = $exon_type;
        $ex->start($fstart);
        $ex->end($fstart);
      } else {
        $ex->start($ex->{'exon'}->{'fstart'} + 1);
        $ex->end($ex->{'exon'}->{'fstart'} + 1);
        
        if ($ex->{'exon'}->{'etype'} eq 'B') {
          $fstart = -1;
          $ex->start($fstart);
          $ex->end($fstart);
        } elsif ($ex->{'exon'}->{'etype'} eq 'M') {
          $ex->{'exon'}->{'fend'} = $fstart;
        }
      }
    }
      
    push @exons, $ex;
  }
    
  return reverse @exons;
}

sub is_coding_gene {
  my ($self, $gene) = @_;
	
  foreach (@{$gene->get_all_Transcripts}) {
    return 1 if $_->translation;
  }
  
  return 0;
}

# Generate title tag which will be used to render z-menu
sub title {
  my ($self, $transcript, $gene) = @_;
  
  my $title = 'Transcript: ' . $transcript->stable_id;
  $title .= '; Gene: ' . $gene->stable_id if $gene->stable_id;
  $title .= '; Location: ' . $transcript->seq_region_name . ':' . $transcript->seq_region_start . '-' . $transcript->seq_region_end;
  
  return $title
}

# Generate title tag for gene which will be used to render z-menu
sub gene_title {
  my ($self, $gene) = @_;
  
  my $title = 'Gene: ' . $gene->stable_id;
  $title .= '; Location: ' . $gene->seq_region_name . ':' . $gene->seq_region_start . '-' . $gene->seq_region_end;
  
  return $title;
}

sub feature_label {
  my $self       = shift;
  my $gene       = shift;
  my $transcript = shift || $gene;
  my $id         = $transcript->external_name || $transcript->stable_id;
     $id         = $transcript->strand == 1 ? "$id >" : "< $id";
  
  return $id if $self->get_parameter('opt_shortlabels') || $transcript == $gene;
  
  my $label = $self->my_config('label_key') || '[text_label] [display_label]';
  
  return $id if $label eq '-';
  
  my $ini_entry = $self->my_colour($self->colour_key($gene, $transcript), 'text');
  
  if ($label =~ /[biotype]/) {
    my $biotype = $transcript->biotype;
       $biotype =~ s/_/ /g;
       $label   =~ s/\[biotype\]/$biotype/g;
  }
  
  $label =~ s/\[text_label\]/$ini_entry/g;
  $label =~ s/\[gene.(\w+)\]/$1 eq 'logic_name' || $1 eq 'display_label' ? $gene->analysis->$1 : $gene->$1/eg;
  $label =~ s/\[(\w+)\]/$1 eq 'logic_name' || $1 eq 'display_label' ? $transcript->analysis->$1 : $transcript->$1/eg;
  
  $id .= "\n$label" unless $label eq '-';
  
  return $id;
}

sub text_details {
  my $self = shift;
  
  if (!$self->{'text_details'}) {
    my %font_details = $self->get_font_details('outertext', 1);
    $self->{'text_details'} = { %font_details, height => [ $self->get_text_width(0, 'Xg', 'Xg', %font_details) ]->[3] + 1 };
  }
  
  return $self->{'text_details'};
}

sub colour_key {
  my $self       = shift;
  my $gene       = shift;
  my $transcript = shift || $gene;
  my $pattern    = $self->my_config('colour_key') || '[biotype]';
  
  # hate having to put ths hack here, needed because any logic_name specific web_data entries
  # get lost when the track is merged - needs rewrite of imageconfig merging code
  return 'merged' if $transcript->analysis->logic_name =~ /ensembl_havana/;
  
  $pattern =~ s/\[gene.(\w+)\]/$1 eq 'logic_name' ? $gene->analysis->$1 : $gene->$1/eg;
  $pattern =~ s/\[(\w+)\]/$1 eq 'logic_name' ? $transcript->analysis->$1 : $transcript->$1/eg;
  
  return lc $pattern;
}

sub max_label_rows { return $_[0]->my_config('max_label_rows') || 2; }

1;