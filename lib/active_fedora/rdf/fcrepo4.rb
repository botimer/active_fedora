require 'rdf'
module ActiveFedora::RDF
  class Fcrepo4 < RDF::StrictVocabulary("http://fedora.info/definitions/v4/repository#")
    property :created
    property :hasVersion
    property :hasVersionLabel
    property :lastModified
  end
end
