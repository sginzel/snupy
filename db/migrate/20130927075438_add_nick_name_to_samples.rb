class AddNickNameToSamples < ActiveRecord::Migration
  def up
  	add_column :samples, :nickname, :string, null: false
  	Sample.transaction do 
	  	Sample.all.each do |s|
	  		s.nickname = s.name.split("/")[-1].to_s
	  		s.save!
	  	end
	  end
	  add_index :samples, :nickname
  end
  
  def down
  	remove_index :samples, :nickname
  	remove_column :samples, :nickname
  end
end
