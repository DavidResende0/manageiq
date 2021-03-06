class VolumeMapping < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CustomActionsMixin

  belongs_to :cloud_volume
  belongs_to :host_initiator

  has_one :storage_resource, :through => :cloud_volume
  has_one :physical_storage, :through => :storage_resource

  belongs_to :ext_management_system, :foreign_key => :ems_id

  supports_not :create
  acts_as_miq_taggable

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def self.class_by_ems(ext_management_system)
    # TODO(lsmola) taken from Orchestration stacks, correct approach should be to have a factory on ExtManagementSystem
    # side, that would return correct class for each provider
    ext_management_system && ext_management_system.class::VolumeMapping
  end

  def self.create_volume_mapping_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating VolumeMapping for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'VolumeMapping',
      :method_name => 'create_volume_mapping',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_volume_mapping(ems_id, options = {})
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find_by(:id => ems_id)
    raise ArgumentError, _("ext_management_system cannot be found") if ext_management_system.nil?

    klass = class_by_ems(ext_management_system)
    klass.raw_create_volume_mapping(ext_management_system, options)
  end

  def self.raw_create_volume_mapping(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_create_volume_mapping must be implemented in a subclass")
  end
end
