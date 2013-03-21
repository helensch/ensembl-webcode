package Bio::EnsEMBL::GlyphSet::phenotype_feature;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub colour_key {
  return lc($_[1]->type);
}

sub my_config { 
  my $self = shift;
	my $term = shift;
	
  if($term eq 'depth' && $self->{'display'} eq 'gene_nolabel') {
    return 999;
  }
  if($term eq 'height' && $self->{'display'} eq 'compact') {
    return 5;
  }
  
	return $self->{'my_config'}->get($term);
}

sub feature_label {
  my ($self, $f) = @_;
  return $self->{'display'} eq 'compact' ? undef : $f->phenotype->description,'overlaid';
}

sub features {
  my $self = shift; 
  my $id   = $self->{'my_config'}->id;
  
  if (!$self->cache($id)) {
    my $slice    = $self->{'container'};
    my $type     = $self->my_config('type');
    my $features = [grep {$_->{_phenotype_id}} @{$slice->get_all_PhenotypeFeatures($type)}];
    
    $self->cache($id, $features);
  }
  
  return $self->cache($id) || [];
}


sub tag {
  my ($self, $f) = @_;
  my $colour = $self->my_colour($self->colour_key($f), 'tag');
  my @tags;
  
  return @tags;
}

sub href {
  my ($self, $f) = @_;
  
  my $type = $f->type;
  my $link;
  my $hub = $self->{'config'}->hub;
  
  # link to search for SSVs
  if($type eq 'SupportingStructuralVariation') {
    my $params = {
      'type'   => 'Search',
      'action' => 'Results',
      'q'      => $f->object_id,
      __clear  => 1
    };
    
    $link = $hub->url($params);
  }
  
  # link to ext DB for QTL
  elsif($type eq 'QTL') {
    my $source = $f->source;
    my $species = uc(join("", map {substr($_,0,1)} split(/\_/, $hub->species)));
    
    $link = $hub->get_ExtURL(
      $source,
      { ID => $f->object_id, SP => $species}
    );
  }
  
  # link to gene or variation page
  else {
    # work out the ID param (e.g. v, g, sv)
    my $id_param = $type;
    $id_param =~ s/[a-z]//g;
    $id_param = lc($id_param);
    
    my $params = {
      'type'      => $type,
      'action'    => 'Phenotype',
      'ph'        => $hub->param('ph'),
      $id_param   => $f->object_id,
      __clear     => 1
    };
  
    $link = $hub->url($params);
  }
  
  return $link;
}

sub title {
  my ($self, $f) = @_;
  my $id     = $f->object_id;
  my $phen   = $f->phenotype->description;
  my $source = $f->source;
  my $type   = $f->type;
  
  # convert the object type e.g. from StructuralVariation to Structural Variation
  # but don't want to convert QTL to Q T L
  $type =~ s/([A-Z])([a-z])/ $1$2/g;
  $type =~ s/^s+//;
  
  my $string = "$type: $id; Phenotype: $phen; Source: $source";
  
  # add phenotype attributes, skip internal dbID ones
  my %attribs = %{$f->get_all_attributes};
  foreach my $attrib(sort grep {!/sample|strain/} keys %attribs) {
    my $value = $attribs{$attrib};
    $string .= "; $attrib: $value";
  }
  
  return $string;
}

1;
