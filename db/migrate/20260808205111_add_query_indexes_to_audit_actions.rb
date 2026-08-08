class AddQueryIndexesToAuditActions < ActiveRecord::Migration[8.1]
  def change
    add_index :audit_actions, [ :created_at, :id ], name: "index_audit_actions_on_created_at_and_id"
    add_index :audit_actions, [ :kind, :created_at, :id ], name: "index_audit_actions_on_kind_created_at_id"
    add_index :audit_actions, [ :author_type, :author_id, :created_at, :id ],
      name: "index_audit_actions_on_author_created_at_id"
    add_index :audit_actions, [ :recipient_type, :recipient_id, :created_at, :id ],
      name: "index_audit_actions_on_recipient_created_at_id"
  end
end
