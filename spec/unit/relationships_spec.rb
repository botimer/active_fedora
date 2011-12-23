require 'spec_helper'

@@last_pid = 0

describe ActiveFedora::Relationships do
    def increment_pid
      @@last_pid += 1    
    end

    before(:each) do
      class SpecNode
        include ActiveFedora::RelationshipsHelper
        include ActiveFedora::Relationships
        include ActiveFedora::SemanticNode
        
        attr_accessor :pid
        def initialize (params={}) 
          self.pid = params[:pid]
        end
        def internal_uri
          'info:fedora/' + pid.to_s
        end
      end
    end
    after(:each) do
      Object.send(:remove_const, :SpecNode)
    end

    it 'should provide #has_relationship' do
      SpecNode.should  respond_to(:has_relationship)
      SpecNode.should  respond_to(:has_relationship)
    end
    describe '#relationships' do
      
      it "should return a hash" do
        SpecNode.relationships.class.should == Hash
      end

    end
    
    describe '#has_relationship' do
      it "should create finders based on provided relationship name" do
        SpecNode.has_relationship("parts", :is_part_of, :inbound => true)
        local_node = SpecNode.new
        local_node.should respond_to(:parts_ids)
        local_node.should respond_to(:parts_query)
        # local_node.should respond_to(:parts)
        local_node.should_not respond_to(:containers)
        SpecNode.has_relationship("containers", :is_member_of)  
        local_node.should respond_to(:containers_ids)
        local_node.should respond_to(:containers_query)
      end
      
      it "should add a subject and predicate to the relationships array" do
        SpecNode.has_relationship("parents", :is_part_of)
        SpecNode.relationships.should have_key(:self)
        SpecNode.relationships[:self].should have_key(:is_part_of)
      end
      
      it "should use :inbound as the subject if :inbound => true" do
        SpecNode.has_relationship("parents", :is_part_of, :inbound => true)
        SpecNode.relationships.should have_key(:inbound)
        SpecNode.relationships[:inbound].should have_key(:is_part_of)
      end
      
      it 'should create inbound relationship finders' do
        SpecNode.expects(:create_inbound_relationship_finders)
        SpecNode.has_relationship("parts", :is_part_of, :inbound => true) 
      end
      
      it 'should create outbound relationship finders' do
        SpecNode.expects(:create_outbound_relationship_finders).times(2)
        SpecNode.has_relationship("parts", :is_part_of, :inbound => false)
        SpecNode.has_relationship("container", :is_member_of)
      end
      
      it "should create outbound relationship finders that return an array of fedora PIDs" do
        SpecNode.has_relationship("containers", :is_member_of, :inbound => false)
        local_node = SpecNode.new
        #local_node.internal_uri = "info:fedora/#{@pid}"
        local_node.pid = @pid
        
        local_node.expects(:rels_ext).returns(stub("rels_ext", :dirty= => true, :content=>'')).at_least_once
        local_node.add_relationship(:is_member_of, "info:fedora/container:A")
        local_node.add_relationship(:is_member_of, "info:fedora/container:B")

        containers_result = local_node.containers_ids
        containers_result.should be_instance_of(Array)
        containers_result.should include("container:A")
        containers_result.should include("container:B")
      end
      
      describe "has_relationship" do
        before do
          class MockHasRelationship 
            include ActiveFedora::SemanticNode
            include ActiveFedora::Relationships
            has_relationship "testing", :has_part, :type=>String
            has_relationship "testing2", :has_member, :type=>String
            has_relationship "testing_inbound", :has_part, :type=>String, :inbound=>true
            attr_accessor :pid
            def internal_uri
              'info:fedora/' + pid.to_s
            end
          end
        end
        after(:each) do
          Object.send(:remove_const, :MockHasRelationship)
        end
          
        it 'should create relationship descriptions both inbound and outbound' do
          @test_object2 = MockHasRelationship.new
          @test_object2.pid = increment_pid
          @test_object2.stubs(:testing_inbound).returns({})
          @test_object2.expects(:rels_ext).returns(stub("rels_ext", :dirty= => true, :content =>'')).at_least_once
          @test_object2.add_relationship(:has_model, ActiveFedora::ContentModel.pid_from_ruby_class(SpecNode))
          @test_object2.should respond_to(:testing_append)
          @test_object2.should respond_to(:testing_remove)
          @test_object2.should respond_to(:testing2_append)
          @test_object2.should respond_to(:testing2_remove)
          #make sure append/remove method not created for inbound rel
          @test_object2.should_not respond_to(:testing_inbound_append)
          @test_object2.should_not respond_to(:testing_inbound_remove)
          
          @test_object2.class.relationships_desc.should == 
          {:inbound=>{"testing_inbound"=>{:type=>String, 
                                         :predicate=>:has_part, 
                                          :inbound=>true, 
                                          :singular=>nil}}, 
           :self=>{"testing"=>{:type=>String, 
                               :predicate=>:has_part, 
                               :inbound=>false, 
                               :singular=>nil},
                   "testing2"=>{:type=>String, 
                                :predicate=>:has_member, 
                                :inbound=>false, 
                                :singular=>nil}}}
        end
      end
    end
      
    describe '#create_inbound_relationship_finders' do
      
      it 'should respond to #create_inbound_relationship_finders' do
        SpecNode.should respond_to(:create_inbound_relationship_finders)
      end
      
      it "should create finders based on provided relationship name" do
        SpecNode.create_inbound_relationship_finders("parts", :is_part_of, :inbound => true)
        local_node = SpecNode.new
        local_node.should respond_to(:parts_ids)
        local_node.should_not respond_to(:containers)
        SpecNode.create_inbound_relationship_finders("containers", :is_member_of, :inbound => true)  
        local_node.should respond_to(:containers_ids)
        local_node.should respond_to(:containers)
        local_node.should respond_to(:containers_from_solr)
        local_node.should respond_to(:containers_query)
      end
      
      it "resulting finder should search against solr and use Model#load_instance to build an array of objects" do
        @sample_solr_hits = [{"id"=>"_PID1_", "has_model_s"=>["info:fedora/afmodel:AudioRecord"]},
                              {"id"=>"_PID2_", "has_model_s"=>["info:fedora/afmodel:AudioRecord"]},
                              {"id"=>"_PID3_", "has_model_s"=>["info:fedora/afmodel:AudioRecord"]}]
        solr_result = mock("solr result", :hits => @sample_solr_hits)
        SpecNode.create_inbound_relationship_finders("parts", :is_part_of, :inbound => true)
        local_node = SpecNode.new()
        local_node.expects(:pid).returns("test:sample_pid")
        SpecNode.expects(:relationships_desc).returns({:inbound=>{"parts"=>{:predicate=>:is_part_of}}}).at_least_once()
        ActiveFedora::SolrService.instance.conn.expects(:query).with("is_part_of_s:info\\:fedora/test\\:sample_pid", :rows=>25).returns(solr_result)
        local_node.parts_ids.should == ["_PID1_", "_PID2_", "_PID3_"]
      end
      
      it "resulting finder should accept :solr as :response_format value and return the raw Solr Result" do
        solr_result = mock("solr result")
        SpecNode.create_inbound_relationship_finders("constituents", :is_constituent_of, :inbound => true)
        local_node = SpecNode.new
        mock_repo = mock("repo")
        mock_repo.expects(:find_model).never
        local_node.expects(:pid).returns("test:sample_pid")
        SpecNode.expects(:relationships_desc).returns({:inbound=>{"constituents"=>{:predicate=>:is_constituent_of}}}).at_least_once()
        ActiveFedora::SolrService.instance.conn.expects(:query).with("is_constituent_of_s:info\\:fedora/test\\:sample_pid", :rows=>101).returns(solr_result)
        local_node.constituents(:response_format => :solr, :rows=>101).should equal(solr_result)
      end
      
      
      it "resulting _ids finder should search against solr and return an array of fedora PIDs" do
        SpecNode.create_inbound_relationship_finders("parts", :is_part_of, :inbound => true)
        local_node = SpecNode.new
        local_node.expects(:pid).returns("test:sample_pid")
        SpecNode.expects(:relationships_desc).returns({:inbound=>{"parts"=>{:predicate=>:is_part_of}}}).at_least_once() 
        ActiveFedora::SolrService.instance.conn.expects(:query).with("is_part_of_s:info\\:fedora/test\\:sample_pid", :rows=>25).returns(mock("solr result", :hits => [Hash["id"=>"pid1"], Hash["id"=>"pid2"]]))
        local_node.parts(:response_format => :id_array).should == ["pid1", "pid2"]
      end
      
      it "resulting _ids finder should call the basic finder with :result_format => :id_array" do
        SpecNode.create_inbound_relationship_finders("parts", :is_part_of, :inbound => true)
        local_node = SpecNode.new
        local_node.expects(:parts).with(:response_format => :id_array)
        local_node.parts_ids
      end

      it "resulting _query finder should call relationship_query" do
        SpecNode.create_inbound_relationship_finders("parts", :is_part_of, :inbound => true)
        local_node = SpecNode.new
        local_node.expects(:relationship_query).with("parts")
        local_node.parts_query
      end
    end
    
    describe '#create_outbound_relationship_finders' do
      
      it 'should respond to #create_outbound_relationship_finders' do
        SpecNode.should respond_to(:create_outbound_relationship_finders)
      end
      
      it "should create finders based on provided relationship name" do
        SpecNode.create_outbound_relationship_finders("parts", :is_part_of)
        local_node = SpecNode.new
        local_node.should respond_to(:parts_ids)
        #local_node.should respond_to(:parts)  #.with(:type => "AudioRecord")  
        local_node.should_not respond_to(:containers)
        SpecNode.create_outbound_relationship_finders("containers", :is_member_of)  
        local_node.should respond_to(:containers_ids)
        local_node.should respond_to(:containers)  
        local_node.should respond_to(:containers_from_solr)  
        local_node.should respond_to(:containers_query)
      end
      
      describe " resulting finder" do
        it "should read from relationships array and use Repository.find_model to build an array of objects" do
          SpecNode.create_outbound_relationship_finders("containers", :is_member_of)
          local_node = SpecNode.new
          local_node.expects(:ids_for_outbound).with(:is_member_of).returns(["my:_PID1_", "my:_PID2_", "my:_PID3_"])
          mock_repo = mock("repo")
          solr_result = mock("solr result", :is_a? => true)
          solr_result.expects(:hits).returns(
                        [{"id"=> "my:_PID1_", "has_model_s"=>["info:fedora/afmodel:SpecNode"]},
                         {"id"=> "my:_PID2_", "has_model_s"=>["info:fedora/afmodel:SpecNode"]}, 
                         {"id"=> "my:_PID3_", "has_model_s"=>["info:fedora/afmodel:SpecNode"]}])

          ActiveFedora::SolrService.instance.conn.expects(:query).with("id:my\\:_PID1_ OR id:my\\:_PID2_ OR id:my\\:_PID3_").returns(solr_result)
          local_node.containers.map(&:pid).should == ["my:_PID1_", "my:_PID2_", "my:_PID3_"]
        end
      
        it "should accept :solr as :response_format value and return the raw Solr Result" do
          solr_result = mock("solr result")
          SpecNode.create_outbound_relationship_finders("constituents", :is_constituent_of)
          local_node = SpecNode.new
          mock_repo = mock("repo")
          mock_repo.expects(:find_model).never
          local_node.expects(:rels_ext).returns(stub('rels-ext', :content=>''))
          ActiveFedora::SolrService.instance.conn.expects(:query).returns(solr_result)
          local_node.constituents(:response_format => :solr).should equal(solr_result)
        end
        
        it "(:response_format => :id_array) should read from relationships array" do
          SpecNode.create_outbound_relationship_finders("containers", :is_member_of)
          local_node = SpecNode.new
          local_node.expects(:ids_for_outbound).with(:is_member_of).returns([])
          local_node.containers_ids
        end
      
        it "(:response_format => :id_array) should return an array of fedora PIDs" do
          SpecNode.create_outbound_relationship_finders("containers", :is_member_of)
          local_node = SpecNode.new
          local_node.expects(:rels_ext).returns(stub("rels_ext", :dirty= => true, :content=>'')).at_least_once
          local_node.add_relationship(:is_member_of, "demo:10")
          result = local_node.containers_ids
          result.should be_instance_of(Array)
          result.should include("demo:10")
        end
        
      end
      
      describe " resulting _ids finder" do
        it "should call the basic finder with :result_format => :id_array" do
          SpecNode.create_outbound_relationship_finders("parts", :is_part_of)
          local_node = SpecNode.new
          local_node.expects(:parts).with(:response_format => :id_array)
          local_node.parts_ids
        end
      end

      it "resulting _query finder should call relationship_query" do
        SpecNode.create_outbound_relationship_finders("containers", :is_member_of)
        local_node = SpecNode.new
        local_node.expects(:relationship_query).with("containers")
        local_node.containers_query
      end
    end
    
    describe ".create_bidirectional_relationship_finder" do
      before(:each) do
        SpecNode.create_bidirectional_relationship_finders("all_parts", :has_part, :is_part_of)
        @local_node = SpecNode.new
        @pid = "test:sample_pid"
        @local_node.pid = @pid
        #@local_node.internal_uri = @uri
      end
      it "should create inbound & outbound finders" do
        @local_node.should respond_to(:all_parts_inbound)
        @local_node.should respond_to(:all_parts_outbound)
      end
      it "should rely on inbound & outbound finders" do      
        @local_node.expects(:all_parts_inbound).with(:rows => 25).returns(["foo1"])
        @local_node.expects(:all_parts_outbound).with(:rows => 25).returns(["foo2"])
        @local_node.all_parts.should == ["foo1", "foo2"]
      end
      it "(:response_format => :id_array) should rely on inbound & outbound finders" do
        @local_node.expects(:all_parts_inbound).with(:response_format=>:id_array, :rows => 34).returns(["fooA"])
        @local_node.expects(:all_parts_outbound).with(:response_format=>:id_array, :rows => 34).returns(["fooB"])
        @local_node.all_parts(:response_format=>:id_array, :rows => 34).should == ["fooA", "fooB"]
      end
      it "(:response_format => :solr) should construct a solr query that combines inbound and outbound searches" do
        # get the id array for outbound relationships then construct solr query by combining id array with inbound relationship search
        @local_node.expects(:ids_for_outbound).with(:has_part).returns(["mypid:1"])
        id_array_query = ActiveFedora::SolrService.construct_query_for_pids(["mypid:1"])
        solr_result = mock("solr result")
        ActiveFedora::SolrService.instance.conn.expects(:query).with("#{id_array_query} OR (is_part_of_s:info\\:fedora/test\\:sample_pid)", :rows=>25).returns(solr_result)
        @local_node.all_parts(:response_format=>:solr)
      end

      it "should register both inbound and outbound predicate components" do
        @local_node.class.relationships[:inbound].has_key?(:is_part_of).should == true
        @local_node.class.relationships[:self].has_key?(:has_part).should == true
      end
    
      it "should register relationship names for inbound, outbound" do
        @local_node.relationship_names.include?("all_parts_inbound").should == true
        @local_node.relationship_names.include?("all_parts_outbound").should == true
      end

      it "should register finder methods for the bidirectional relationship name" do
        @local_node.should respond_to(:all_parts)
        @local_node.should respond_to(:all_parts_ids)
        @local_node.should respond_to(:all_parts_query)
        @local_node.should respond_to(:all_parts_from_solr)
      end

      it "resulting _query finder should call relationship_query" do
        SpecNode.create_bidirectional_relationship_finders("containers", :is_member_of, :has_member)
        local_node = SpecNode.new
        local_node.expects(:relationship_query).with("containers")
        local_node.containers_query
      end
    end
    
    describe "#has_bidirectional_relationship" do
      it "should ..." do
        SpecNode.expects(:create_bidirectional_relationship_finders).with("all_parts", :has_part, :is_part_of, {})
        SpecNode.has_bidirectional_relationship("all_parts", :has_part, :is_part_of)
      end

      it "should have relationships_by_name and relationships hashes contain bidirectionally related objects" do
        SpecNode.has_bidirectional_relationship("all_parts", :has_part, :is_part_of)
        @local_node = SpecNode.new
        @local_node.pid = "mypid1"
        @local_node2 = SpecNode.new
        @local_node2.pid = "mypid2"
        model_def = ActiveFedora::ContentModel.pid_from_ruby_class(SpecNode)
        @local_node.expects(:rels_ext).returns(stub("rels_ext", :dirty= => true, :content=>'')).at_least_once
        @local_node.add_relationship(:has_model, model_def)
        @local_node2.expects(:rels_ext).returns(stub("rels_ext", :dirty= => true, :content=>'')).at_least_once
        @local_node2.add_relationship(:has_model, model_def)
        @local_node.add_relationship(:has_part, @local_node2)
        @local_node2.add_relationship(:has_part, @local_node)
        @local_node.ids_for_outbound(:has_part).should == [@local_node2.pid]
        @local_node.ids_for_outbound(:has_model).should == ['afmodel:SpecNode']
        @local_node2.ids_for_outbound(:has_part).should == [@local_node.pid]
        @local_node2.ids_for_outbound(:has_model).should == ['afmodel:SpecNode']
        @local_node.relationships_by_name(false).should == {:self=>{"all_parts_outbound"=>[@local_node2.internal_uri]},:inbound=>{"all_parts_inbound"=>[]}}
        @local_node2.relationships_by_name(false).should == {:self=>{"all_parts_outbound"=>[@local_node.internal_uri]},:inbound=>{"all_parts_inbound"=>[]}}
      end
    end

end