package EnsEMBL::Web::Component::Help::Faq;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::DBSQL::WebsiteAdaptor;

use base qw(EnsEMBL::Web::Component::Help);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  my $id = $hub->param('id') || $hub->param('feedback');
  $id+=0;
  my $html = qq(<h2>FAQs</h2>);
  
  my $adaptor = EnsEMBL::Web::DBSQL::WebsiteAdaptor->new($hub);
  my $args;

  my %category_lookup = (
    'archives'       => 'Archives',  
    'genes'          => 'Genes',    
    'assemblies'     => 'Genome assemblies',    
    'comparative'    => 'Comparative genomics',
    'regulation'     => 'Regulation',         
    'variation'      => 'Variation',         
    'data'           => 'Export, uploads and downloads',  
    'z_data'         => 'Other data',          
    'core_api'       => 'Core API',           
    'compara_api'    => 'Compara API',       
    'compara'        => 'Compara API',       
    'variation_api'  => 'Variation API',    
    'regulation_api' => 'Regulation API',  
    'web'            => 'Website',
  );

  if ($id) {
    $args->{'id'} = $id;
  }
  my @faqs = sort {$a->{'category'} cmp $b->{'category'}} @{$adaptor->fetch_faqs($args)}; 

  ## Can't do category via SQL any more, as it has been moved into 'data' 
  my $single_cat = $hub->param('cat');

  if (scalar(@faqs) > 0) {
  
    my $style = 'text-align:right;margin-right:2em';
    my $category = '';

    foreach my $faq (@faqs) {
      next unless $faq;
      next if $single_cat && $faq->{'category'} ne $single_cat;

      unless ($single_cat) {
        if ($faq->{'category'} && $category ne $faq->{'category'}) {
          $html .= '<h3>'.$category_lookup{$faq->{'category'}}.'</h3>';
        }
      }

      $html .= sprintf(qq(<p class="space-below"><a href="/Help/Faq?id=%s" id="faq%s">%s</a></p>), $faq->{'id'}, $faq->{'id'}, $faq->{'question'});
      if ($hub->param('feedback') && $hub->param('feedback') == $faq->{'id'}) {
        $html .= qq(<div style="$style">Thank you for your feedback</div>);
      } else {
        $html .= $self->help_feedback($style, $faq->{'id'}, return_url => '/Help/Faq', type => 'Faq');
      }
      $category = $faq->{'category'};
    }

    if (scalar(@faqs) == 1) {
      $html .= qq(<p><a href="/Help/Faq" class="popup">More FAQs</a></p>);
    }
  }

  $html .= qq(<hr /><p style="margin-top:1em">If you have any other questions about Ensembl, please do not hesitate to 
<a href="/Help/Contact" class="popup">contact our HelpDesk</a>. You may also like to subscribe to the 
<a href="http://www.ensembl.org/info/about/contact/mailing.html" class="cp-external">developers' mailing list</a>.</p>);

  return $html;
}

1;
