require 'spec_helper'

describe ActiveFedora::NtriplesRDFDatastream do
  describe "an instance with content" do
    before do
      class MyDatastream < ActiveFedora::NtriplesRDFDatastream
        property :created, predicate: RDF::DC.created
        property :title, predicate: RDF::DC.title
        property :publisher, predicate: RDF::DC.publisher
        property :creator, predicate: RDF::DC.creator
        property :educationLevel, predicate: RDF::DC.educationLevel
        property :based_near, predicate: RDF::FOAF.based_near
        property :related_url, predicate: RDF::RDFS.seeAlso
      end
      @subject = MyDatastream.new(double('inner object', pid: 'test:1', :new_record? => true), 'descMetadata')
      @subject.content = File.new('spec/fixtures/mixed_rdf_descMetadata.nt').read
    end
    after do
      Object.send(:remove_const, :MyDatastream)
    end
    it "should have a subject" do
      expect(@subject.rdf_subject).to eq("info:fedora/test:1")
    end
    it "should have controlGroup" do
      expect(@subject.controlGroup).to eq('M')
    end
    it "should have mimeType" do
      expect(@subject.mimeType).to eq('application/n-triples')
    end
    it "should have dsid" do
      expect(@subject.dsid).to eq('descMetadata')
    end
    it "should have fields" do
      expect(@subject.created).to eq([Date.parse('2010-12-31')])
      expect(@subject.title).to eq(["Title of work"])
      expect(@subject.publisher).to eq(["Penn State"])
      expect(@subject.based_near).to eq(["New York, NY, US"])
      expect(@subject.related_url.length).to eq(1)
      expect(@subject.related_url.first.rdf_subject).to eq("http://google.com/")
    end

    it "should be able to call enumerable methods on the fields" do
      expect(@subject.title.join(', ')).to eq("Title of work")
      expect(@subject.title.count).to eq(1)
      expect(@subject.title.size).to eq(1)
      expect(@subject.title[0]).to eq("Title of work")
      expect(@subject.title.to_a).to eq(["Title of work"])
      val = []
      @subject.title.each_with_index {|v, i| val << "#{i}. #{v}"}
      expect(val).to eq(["0. Title of work"])
    end

    it "should return fields that are not TermProxies" do
      expect(@subject.created).to be_kind_of Array
    end
    it "should have method missing" do
      expect{@subject.frank}.to raise_exception NoMethodError
    end

    it "should set fields" do
      @subject.publisher = "St. Martin's Press"
      expect(@subject.publisher).to eq(["St. Martin's Press"])
    end
    it "should set rdf literal fields" do
      @subject.creator = RDF.Literal("Geoff Ryman")
      expect(@subject.creator).to eq(["Geoff Ryman"])
    end
    it "should append fields" do
      @subject.publisher << "St. Martin's Press"
      expect(@subject.publisher).to eq(["Penn State", "St. Martin's Press"])
    end
    it "should delete fields" do
      @subject.related_url.delete(RDF::URI("http://google.com/"))
      expect(@subject.related_url).to eq([])
    end
  end

  describe "some dummy instances" do
    before do
      @one = ActiveFedora::RDFDatastream.new('fakepid', 'myFoobar')
      @two = ActiveFedora::RDFDatastream.new('fakepid', 'myQuix')
    end
    it "should generate predictable prexies" do
      expect(@one.apply_prefix("baz")).to eq('my_foobar__baz')
      expect(@two.apply_prefix("baz")).to eq('my_quix__baz')
    end
  end

  describe "an instance with a custom subject" do
    before do
      class MyDatastream < ActiveFedora::NtriplesRDFDatastream
        rdf_subject { |ds| "info:fedora/#{ds.pid}/content" }
        property :created, predicate: RDF::DC.created
        property :title, predicate: RDF::DC.title
        property :publisher, predicate: RDF::DC.publisher
        property :based_near, predicate: RDF::FOAF.based_near
        property :related_url, predicate: RDF::RDFS.seeAlso
      end
      @inner_object = double('inner object', pid: 'test:1', :new_record? => true)
      @subject = MyDatastream.new(@inner_object, 'mixed_rdf')
      allow(@subject).to receive_messages(pid: 'test:1')
      allow(@subject).to receive_messages(:new_record? => false)
      @subject.content = File.new('spec/fixtures/mixed_rdf_descMetadata.nt').read
    end

    after do
      Object.send(:remove_const, :MyDatastream)
    end

    it "should have fields" do
      expect(@subject.title).to eq(["Title of datastream"])
    end

    it "should have a custom subject" do
      expect(@subject.rdf_subject).to eq('info:fedora/test:1/content')
    end
  end

  describe "a new instance" do
    before(:each) do
      class MyDatastream < ActiveFedora::NtriplesRDFDatastream
        property :publisher, predicate: RDF::DC.publisher
      end
      @subject = MyDatastream.new(@inner_object, 'mixed_rdf')
      allow(@subject).to receive_messages(pid: 'test:1', repository: ActiveFedora::Base.connection_for_pid(0))
    end
    after(:each) do
      Object.send(:remove_const, :MyDatastream)
    end
    it "should support to_s method" do
      expect(@subject.publisher.to_s).to eq([].to_s)
      @subject.publisher = "Bob"
      expect(@subject.publisher.to_s).to eq(["Bob"].to_s)
      @subject.publisher << "Jim"
      expect(@subject.publisher.to_s).to eq(["Bob", "Jim"].to_s)
    end
 end

  describe "solr integration" do
    before(:all) do
      class MyDatastream < ActiveFedora::NtriplesRDFDatastream
        property :created, predicate: RDF::DC.created do |index|
          index.as :sortable, :displayable
          index.type :date
        end
        property :title, predicate: RDF::DC.title do |index|
          index.as :stored_searchable, :sortable
          index.type :text
        end
        property :publisher, predicate: RDF::DC.publisher do |index|
          index.as :facetable, :sortable, :stored_searchable
        end
        property :based_near, predicate: RDF::FOAF.based_near do |index|
          index.as :facetable, :stored_searchable
          index.type :text
        end
        property :related_url, predicate: RDF::RDFS.seeAlso do |index|
          index.as :stored_searchable
        end
        property :rights, predicate: RDF::DC.rights
      end
      @subject = MyDatastream.new(@inner_object, 'solr_rdf')
      @subject.content = File.new('spec/fixtures/solr_rdf_descMetadata.nt').read
    end
    after(:all) do
      Object.send(:remove_const, :MyDatastream)
    end
    before(:each) do
      allow(@subject).to receive_messages(pid: 'test:1')
      @subject.serialize
    end
    it "should provide .to_solr and return a SolrDocument" do
      expect(@subject).to respond_to(:to_solr)
      expect(@subject.to_solr).to be_kind_of(Hash)
    end

    it "should have a solr_name method" do
      expect(MyDatastream.new(nil, 'descMetadata').primary_solr_name(:based_near)).to eq 'desc_metadata__based_near_tesim'
      expect(MyDatastream.new(nil, 'props').primary_solr_name(:title)).to eq 'props__title_tesim'
    end

    it "should optionally allow you to provide the Solr::Document to add fields to and return that document when done" do
      doc = Hash.new
      expect(@subject.to_solr(doc)).to eq(doc)
    end
    it "should iterate through @fields hash" do
      solr_doc = @subject.to_solr
      expect(solr_doc[ActiveFedora::SolrService.solr_name("solr_rdf__publisher", type: :string)]).to eq(["publisher1"])
      expect(solr_doc[ActiveFedora::SolrService.solr_name("solr_rdf__publisher", :sortable)]).to eq("publisher1")
      expect(solr_doc[ActiveFedora::SolrService.solr_name("solr_rdf__publisher", :facetable)]).to eq(["publisher1"])
      expect(solr_doc[ActiveFedora::SolrService.solr_name("solr_rdf__based_near", type: :string)]).to eq(["coverage1", "coverage2"])
      expect(solr_doc[ActiveFedora::SolrService.solr_name("solr_rdf__based_near", :facetable)]).to eq(["coverage1", "coverage2"])
      expect(solr_doc[ActiveFedora::SolrService.solr_name("solr_rdf__created", :sortable, type: :date)]).to eq("2009-10-10T00:00:00Z")
      expect(solr_doc[ActiveFedora::SolrService.solr_name("solr_rdf__created", :displayable)]).to eq(["2009-10-10"])
      expect(solr_doc[ActiveFedora::SolrService.solr_name("solr_rdf__title", type: :string)]).to eq(["fake-title"])
      expect(solr_doc[ActiveFedora::SolrService.solr_name("solr_rdf__title", :sortable)]).to eq("fake-title")
      expect(solr_doc[ActiveFedora::SolrService.solr_name("solr_rdf__related_url", type: :string)]).to eq(["http://example.org/"])
    end

    describe "with an actual object" do
      before(:each) do
        class Foo < ActiveFedora::Base
          has_metadata "descMetadata", type: MyDatastream
          has_attributes :created, :title, :publisher, :based_near, :related_url, :rights, datastream: :descMetadata, multiple: true
        end
        @obj = MyDatastream.new(@inner_object, 'solr_rdf')
        repository = double()
          allow(@obj).to receive_messages(repository: repository, pid: 'test:1')
          allow(repository).to receive(:modify_datastream)
          allow(repository).to receive(:add_datastream)
        @obj.created = Date.parse("2012-03-04")
        @obj.title = "Of Mice and Men, The Sequel"
        @obj.publisher = "Bob's Blogtastic Publishing"
        @obj.based_near = ["Tacoma, WA", "Renton, WA"]
        @obj.related_url = "http://example.org/blogtastic/"
        @obj.rights = "Totally open, y'all"
        @obj.save
      end
      after do
        Object.send(:remove_const, :Foo)
      end


      describe ".fields()" do
        it "should return the right fields" do
          expect(@obj.send(:fields).keys).to eq(["created", "title", "publisher", "based_near", "related_url"])
        end
        it "should return the right values" do
          fields = @obj.send(:fields)
          expect(fields[:related_url][:values]).to eq(["http://example.org/blogtastic/"])
          expect(fields[:based_near][:values]).to eq(["Tacoma, WA", "Renton, WA"])
        end
        it "should return the right type information" do
          fields = @obj.send(:fields)
          expect(fields[:created][:type]).to eq(:date)
        end
      end
      describe ".to_solr()" do
        it "should return the right fields" do
          expect(@obj.to_solr.keys).to include(ActiveFedora::SolrService.solr_name("solr_rdf__related_url", type: :string),
                ActiveFedora::SolrService.solr_name("solr_rdf__publisher", type: :string),
                ActiveFedora::SolrService.solr_name("solr_rdf__publisher", :sortable),
                ActiveFedora::SolrService.solr_name("solr_rdf__publisher", :facetable),
                ActiveFedora::SolrService.solr_name("solr_rdf__created", :sortable, type: :date),
                ActiveFedora::SolrService.solr_name("solr_rdf__created", :displayable),
                ActiveFedora::SolrService.solr_name("solr_rdf__title", type: :string),
                ActiveFedora::SolrService.solr_name("solr_rdf__title", :sortable),
                ActiveFedora::SolrService.solr_name("solr_rdf__based_near", type: :string),
                ActiveFedora::SolrService.solr_name("solr_rdf__based_near", :facetable))

        end

        it "should return the right values" do
          expect(@obj.to_solr[ActiveFedora::SolrService.solr_name("solr_rdf__related_url", type: :string)]).to eq(["http://example.org/blogtastic/"])
          expect(@obj.to_solr[ActiveFedora::SolrService.solr_name("solr_rdf__based_near", type: :string)]).to eq(["Tacoma, WA","Renton, WA"])
        end
      end
    end
  end
end
