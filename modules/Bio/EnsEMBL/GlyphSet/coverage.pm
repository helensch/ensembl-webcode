package Bio::EnsEMBL::GlyphSet::coverage;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
use Data::Dumper;
use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code variation_class);

sub init_label {
  my $self = shift;
  my $Config         = $self->{'config'};
  my $coverage_obj   = $Config->{'transcript'}->{'coverage_obj'};
  return unless @$coverage_obj;
  my $text  =  @$coverage_obj ? "Resequence coverage" : "No reseq. coverage";
  $self->label(new Sanger::Graphics::Glyph::Text({
    'text'      => $text,
    'font'      => 'Tiny',
    'absolutey' => 1,
  }));
}


sub _init {
  my ($self) = @_;
  my $type = $self->check();
  my $Config         = $self->{'config'};
  my $transcript     = $Config->{'transcript'}->{'transcript'};
  my @coverage_levels = sort { $a <=> $b } @{$Config->{'transcript'}->{'coverage_level'}};
  my $max_coverage   = $coverage_levels[-1];
  my $min_coverage   = $coverage_levels[0] || $coverage_levels[1];
  my $coverage_obj   = $Config->{'transcript'}->{'coverage_obj'};

  unless (@$coverage_obj && @coverage_levels) {
    $self->push(new Sanger::Graphics::Glyph::Space({
      'x'         => 1,
      'y'         => 0,
      'height'    => 1,
      'width'     => 1,
      'absolutey' => 1,
    }) );
    return;
  }
  my $sample         = $Config->{'transcript'}->{'sample'};
  my $A = $Config->get( $type, 'type' ) eq 'bottom' ? 0 : 1;

  my %draw_coverage = (
    $coverage_levels[0] => [0, "grey70"],
    $coverage_levels[1] => [1, "grey40"],
  );


  # Drawing stuff
  my $fontname      = $Config->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'};
  my($font_w_bp, $font_h_bp) = $Config->texthelper->px2bp($fontname);

  foreach my $coverage ( sort { $a->[2]->level <=> $b->[2]->level } @$coverage_obj  ) {
    my $level  = $coverage->[2]->level;
    my $y =  $draw_coverage{$level}[0];
    my $z = 2+$y;# -19+$y;
       $y =  1 - $y if $A; 
       $y *= 2;
    my $h = 3 - $y;
       $y = 0;
    # Draw ------------------------------------------------
    my $S =  $coverage->[0];
    my $E =  $coverage->[1];
    my $width = $font_w_bp * length( $level );
    my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
    my $start = $coverage->[2]->start() + $offset;
    my $end   = $coverage->[2]->end() + $offset;
    my $pos   = "$start-$end";

    my $display_level = $level == $max_coverage ? ">".($level-1) : $level;
    my $bglyph = new Sanger::Graphics::Glyph::Rect({
      'x'         => $S,
      'y'         => 8-$h,
      'height'    => $h,                            #$y,
      'width'     => $E-$S+1,
      'colour'    => $draw_coverage{$level}->[1],
      'absolutey' => 1,
      'zmenu' => {
        'caption' => 'Resequencing read coverage: '.$display_level,
        "12:bp $pos" => '',
        "14:$sample" => '',
      },
      'z'    => $z
    });
    #$self->join_tag( $bglyph, "$S:$E:$level", $A,$A, $draw_coverage{$level}->[1], 'fill',  $z );
    #$self->join_tag( $bglyph, "$S:$E:$level", 1-$A,$A, $draw_coverage{$level}->[1], 'fill',  $z );
    $self->push( $bglyph );
  }
}

sub error_track_name { return 'read coverage'; }

1;
