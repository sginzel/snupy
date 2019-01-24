require 'test_helper'

class EntityTest < ActiveSupport::TestCase
	################################################################
	######### check associations ###################################
	################################################################
	test "should have tags" do
		assert entities(:father1).tags.size > 0
	end

	test "should belong to institution" do
		assert entities(:father1).institution == institutions(:ukd)
	end

	test "should have users" do
		assert entities(:father1).users.size > 0
	end

	test "should have organism" do
		assert !entities(:father1).organism.nil?
	end

	test "Should not save without tags" do
		ent = entities(:father1).clone
		ent.name = ent.name + "_test"
		ent.id = nil
		assert !ent.save, ent.errors.pretty_inspect
	end

	test "should not save without name or entity group" do
		ent = entities(:father1).clone
		ent.name = ""
		ent.entity_group_id = nil
		ent.id = nil
		assert !ent.save
	end

	test "should modify tags" do
		ent = entities(:father1)
		assert_difference('ent.tags.size', 1) do
			ent.tags << Tag.where("object_type" => "Entity").first
			ent.save
		end
	end

	test "should modify entity group" do
		ent = entities(:father1)
		ent.entity_group = entity_groups(:tumor_normal)
		assert ent.save, "cant change entity group."
	end

	test "should have samples" do
		assert entities(:father1).samples.count > 0
	end

	test "should have VcfFiles" do
		assert entities(:father1).vcf_files.count > 0
	end

	################################################################
	######### check authentification ###############################
	################################################################
	test "should be visible for normal users" do
		user = users(:normal_user)
		ent = entities(:father1)
		assert user.visible(Entity).include?(ent), "user cant access the entity"
		assert user.owned(Entity).include?(ent), "user doesnt own the entity"
	end

	test "should not be visible or editable for foreign users" do
		user = users(:foreign_user)
		ent = entities(:father1)
		assert !user.visible(Entity).include?(ent), "foreign user can see the entity"
		assert !user.editable(Entity).include?(ent), "foreign user can edit the entity"
		assert !user.owned(Entity).include?(ent), "foreign user owns the entity"
	end

	test "should be editable for managers and owners" do

		data_manager = users(:data_manager)
		research_manager = users(:research_manager)
		ent = entities(:father1)

		assert assert data_manager.visible(Entity).include?(ent), "data manager can't see the entity"
		assert assert data_manager.editable(Entity).include?(ent), "data manager can't edit the entity"
		assert assert !data_manager.owned(Entity).include?(ent), "data manager owns the entity"

		assert assert research_manager.visible(Entity).include?(ent), "research manager can't see the entity"
		assert assert research_manager.editable(Entity).include?(ent), "research manager can't edit the entity"
		assert assert !research_manager.owned(Entity).include?(ent), "research manager owns the entity"

	end


	################################################################
	######### check data ###########################################
	################################################################


end
