class CopyTitleToStashEngine < ActiveRecord::Migration[4.2]
  def change
    execute <<-SQL
      UPDATE stash_engine_resources r
      LEFT JOIN  dcs_titles t
      ON t.resource_id = r.id
      SET r.title = COALESCE(t.title, '');
    SQL
  end
end
