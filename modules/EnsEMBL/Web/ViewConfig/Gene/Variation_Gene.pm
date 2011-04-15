# $Id$

package EnsEMBL::Web::ViewConfig::Gene::Variation_Gene;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self       = shift;
  my $variations = $self->species_defs->databases->{'DATABASE_VARIATION'};
  
  $self->_set_defaults(qw(
    consequence_format  ensembl
    show_scores         no
    panel_image         on 
    context             100
    hgvs                transcript
    panel_transcript    on
    image_width         800
    reference),         ''
  );
  
  $self->_set_defaults("opt_pop_$_" => 'off') for @{$variations->{'DISPLAY_STRAINS'}};
  $self->_set_defaults("opt_pop_$_" => 'on')  for @{$variations->{'DEFAULT_STRAINS'}};
  $self->_set_defaults("opt_pop_$variations->{'REFERENCE_STRAIN'}" => 'off');

  # Add source information if we have a variation database
  if ($variations) {
    foreach (keys %{$variations->{'tables'}{'source'}{'counts'} || {}}){
      my $name = 'opt_' . lc $_;
      $name    =~ s/\s+/_/g;
      $self->_set_defaults($name => 'on');
    }
  }

  my %options = EnsEMBL::Web::Constants::VARIATION_OPTIONS; # Add other options

  foreach (keys %options) {
    my %hash = %{$options{$_}};
    
    foreach my $key (keys %hash) {
      $self->_set_defaults(lc $key => $hash{$key}[0]);
    }
  }

  $self->add_image_configs({qw(
    genesnpview_gene       nodas  
    genesnpview_transcript nodas
  )});
  
  $self->storable = 1;
  $self->nav_tree = 1;
}

sub form {
  my $self       = shift;
  my $hub        = $self->hub;
  my %options    = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my %validation = %{$options{'variation'}};
  my %class      = %{$options{'class'}};
  my %type       = %{$options{'type'}};
  
  # Add source selection
  $self->add_fieldset('Variation source');
  
  foreach (sort keys %{$hub->table_info('variation', 'source')->{'counts'}}) {
    my $name = 'opt_' . lc($_);
    $name =~ s/\s+/_/g;
    
    $self->add_form_element({
      type  => 'CheckBox', 
      label => $_,
      name  => $name,
      value => 'on',
      raw   => 1
    });
  }
  
  # Add class selection
  $self->add_fieldset('Variation class');
  
  foreach (keys %class) {
    $self->add_form_element({
      type  => 'CheckBox',
      label => $class{$_}[1],
      name  => lc($_),
      value => 'on',
      raw   => 1
    });
  }
  
  # Add Validation selection
  $self->add_fieldset('Validation');
  
  foreach (keys %validation) {
    $self->add_form_element({
      type  => 'CheckBox',
      label => $validation{$_}[1],
      name  =>  lc($_),
      value => 'on',
      raw   => 1
    });
  }
  
  # Add type selection
  $self->add_fieldset('Consequence options');
  
  $self->add_form_element({
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Type of consequences to display',
    name   => 'consequence_format',
    values => [
      { value => 'ensembl',  name => 'Ensembl terms'           },
      { value => 'so',       name => 'Sequence Ontology terms' },
      { value => 'ncbi',     name => 'NCBI terms'              },
    ]
  });  
  
  if ($hub->species =~ /homo_sapiens/i) {
    $self->add_form_element({
      type  => 'CheckBox',
      label => 'Show SIFT and PolyPhen scores',
      name  => 'show_scores',
      value => 'yes',
      raw   => 1,
    });
  }
  
  # Add type selection
  $self->add_fieldset('Consequence type');
  
  foreach (sort { $type{$a}->[2] <=> $type{$b}->[2] } keys %type) { 
    next if $_ eq 'opt_sara';
    
    $self->add_form_element({
      type  => 'CheckBox',
      label => $type{$_}[1],
      name  => lc($_),
      value => 'on',
      raw   => 1
    });
  }

  # Add context selection
  $self->add_fieldset('Intron Context');
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Intron Context',
    values => [
      { value => '20',   name => '20bp' },
      { value => '50',   name => '50bp' },
      { value => '100',  name => '100bp' },
      { value => '200',  name => '200bp' },
      { value => '500',  name => '500bp' },
      { value => '1000', name => '1000bp' },
      { value => '2000', name => '2000bp' },
      { value => '5000', name => '5000bp' },
      { value => 'FULL', name => 'Full Introns' }
    ]
  });
}

1;
