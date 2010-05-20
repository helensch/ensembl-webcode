package EnsEMBL::Web::Component::Variation::VariationSummary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);
use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;


sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '';
 
  ## first check we have a location
  if ( $object->not_unique_location ){
    return $self->_info(
      'A unique location can not be determined for this Variation',
      $object->not_unique_location
    );
  }

 
  ## set path information for LD calculations
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE = $object->species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH = $object->species_defs->ENSEMBL_TMP_TMP;

  ## Add validation status
  my $stat;
  my @status = @{$object->status};
  if ( @status ) {
  my $snp_name = $object->name;
  my (@status_list, $hapmap_html);
  foreach my $status (@status) {
    if ($status eq 'hapmap') {
      $hapmap_html = "<b>HapMap SNP</b>", $object->get_ExtURL_link($snp_name, 'HAPMAP', $snp_name);
    }
    elsif ($status eq 'failed') {
      my $description = $object->vari->failed_description;
      return $status;
    }
    else {
      $status = "frequency" if $status eq 'freq';
      push @status_list, $status;
    }
  }
  $stat = join(", ", @status_list);
  if ($stat) {
    if ($stat eq 'observed' or $stat eq 'non-polymorphic') {
      $html = '<b>'.ucfirst($stat).'</b> ';
    } else {
      $stat = "Proven by <b>$stat</b> ";
    }
    $stat .= ' (<i>Feature tested and validated by a non-computational method</i>).<br /> ';
  }
   $stat .= $hapmap_html;
  } else { 
   $stat = "Unknown";
  }

   unless ($stat=~/^\w/) { $stat = "Undefined"; }
   $html .= qq(
       <dl class="summary">
      <dt>Validation status</dt>
      <dd> $stat</dd>);
      
  

  ## HGVS NOTATIONS
  my $sa = $object->vari->adaptor->db->dnadb->get_SliceAdaptor();
  
  my %mappings = %{ $object->variation_feature_mapping }; 
  my $loc;
  if( keys %mappings == 1 ) {
    ($loc) = values %mappings;
  } else { 
    $loc = $mappings{$object->param('vf')};
  }
  
  if(defined($sa)) {
    
    # get vf object
    my $vf;
    
    foreach my $test_vf(@{$object->vari->get_all_VariationFeatures()}) {
      if(
        $test_vf->seq_region_start == $loc->{start}
        && $test_vf->seq_region_end == $loc->{end}
        && $test_vf->seq_region_name eq $loc->{Chr}
      ) {
        $vf = $test_vf;
      }
    }
    
    if(defined($vf)) {
      my (@hgvs, $hgvs, $hgvs_html, $prev_trans);
      
      # go via transcript variations (should be faster than slice)
      foreach my $tv(@{$vf->get_all_TranscriptVariations()}) {
        next unless defined($tv->{'_transcript_stable_id'});
        next if $tv->{'_transcript_stable_id'} eq $prev_trans;
        $prev_trans = $tv->{'_transcript_stable_id'};
        
        @hgvs = @{$vf->get_all_hgvs_notations($tv->transcript, 'c')};
        $hgvs = join '<br/>', @hgvs;
        $hgvs =~ s/ENS(...)?T\d+/'<a href="'.$object->_url({
          type => 'Transcript',
          action => $object->species_defs->databases->{'DATABASE_VARIATION'}->{'#STRAINS'} > 0 ? 'Population' : 'Summary',
          db     => 'core',
          r      => undef,
          t      => $&,
          v      => $object->name,
          source => $object->vari->source}).'">'.$&.'<\/a>'/eg;
        $hgvs_html .= $hgvs.'<br/>' if $hgvs;
      }
      
      # alternative method going via slice      
      #foreach my $trans(@{$vf->feature_Slice->get_all_Transcripts()}) {
      #  @hgvs = @{$vf->get_all_hgvs_notations($trans, 'c')};
      #  $hgvs = join '<br/>', @hgvs;
      #  $hgvs =~ s/ENS(...)?T\d+/'<a href="'.$object->_url({
      #    type => 'Transcript',
      #    action => $object->species_defs->databases->{'DATABASE_VARIATION'}->{'#STRAINS'} > 0 ? 'Population' : 'Summary',
      #    db     => 'core',
      #    r      => undef,
      #    t      => $&,
      #    v      => $object->name,
      #    source => $object->vari->source}).'">'.$&.'<\/a>'/eg;
      #  $hgvs_html .= $hgvs.'<br/>' if $hgvs;
      #}
      
      $hgvs_html ||= "<h5>None</h5>";
      
      $html .= qq{<dl class="summary"><dt>HGVS names</dt><dd>$hgvs_html</dd></dl>};
    }
  }

  ## Add LD data  
  my $ld_html;
  my $label = "Linkage disequilibrium data";

   ## First check that a location has been selected:
  if ($object->core_objects->location) { 
    if  ($object->species_defs->databases->{'DATABASE_VARIATION'}{'DEFAULT_LD_POP'}) {
      my %pop_names = %{_ld_populations($object) ||{} };
      my %tag_data  = %{$object->tagged_snp ||{} };
      my %ld = (%pop_names, %tag_data);
      if  (keys %ld) {
        $ld_html = link_to_ldview( $object, \%ld); 
      } else {
        $ld_html = "<h5>No linkage data for this SNP</h5>";
      }  
    } else {
      $ld_html = "<h5>No linkage data available for this species</h5>";
    }
  } ## If no location selected direct the user to pick one from the summary panel 
   else {
     $ld_html = "You must select a location from the panel above to see Linkage disequilibrium data";
  }
   $html .= qq(<dt>$label</dt>
      <dd> $ld_html</dd></dl>);
       
  return $html;
}

sub link_to_ldview {

  ### LD
  ### Arg1        : object
  ### Arg2        : hash ref of population data
  ### Example     : link_to_ldview($object, \%pop_data);
  ### Description : Make links from these populations to LDView
  ### Returns  Table of HTML links to LDView

  my ($object, $pops ) = @_;
  my $output = "<table width='100%'  border=0><tr>";
  $output .="<td> <b>Links to Linkage disequilibrium data  per population:</b></td></tr><tr>";
  my $count = 0; 
  for my $pop_name (sort {$a cmp $b} keys %$pops) {
    my $tag = $pops->{$pop_name} eq 1 ? "" : " (Tag SNP)"; 
    # reset r param based on variation feature location and a default context of 20 kb
    my $ld_region = $object->ld_location;
    my $url = $object->_url({ 'type' => 'Location', 'action' =>'LD','r' => $ld_region, 'v' => $object->name, 'vf' =>$object->vari->dbID, 'pop1' => $pop_name , 'focus' => 'variation'});
    $count++;
     $output .= "<td><a href=$url>$pop_name</a>$tag</td>";  
    if ($count ==3) {
      $count = 0;
      $output .= "</tr><tr>";
    }
  }
  $output .= "</tr></table>";
  return  $output;
}

sub _ld_populations {

  ### LD
  ### Arg1        : object
  ### Example     : ld_populations()
  ### Description : data structure with population id and name of pops
  ### with LD info for this SNP
  ### Returns  hashref

  my $object = shift; 

  my $pop_ids = $object->ld_pops_for_snp; 
  return {} unless @$pop_ids;

  my %pops;
  foreach (@$pop_ids) {
    my $pop_obj = $object->pop_obj_from_id($_);
    $pops{ $pop_obj->{$_}{Name} } = 1;
  }
  return \%pops;
}

1;
