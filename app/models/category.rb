# == Schema Information
#
# Table name: categories
#
#  id          :bigint           not null, primary key
#  title       :string
#  description :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :integer
#  parent_id   :integer
#  active      :boolean          default(TRUE), not null
#  deletable   :boolean          default(TRUE), not null
#  slug        :string
#

class Category < ApplicationRecord

  before_update  :protect_unchangeables
  # before_destroy :protect_unchangeables
  before_create  :set_slug

  has_many :subcategories, class_name: 'Category', foreign_key: "parent_id", dependent: :destroy
  has_many :inventory_items, class_name: 'Inventory::Item'
  has_many :inventory_notes, class_name: 'Inventory::Note'
  belongs_to :parent, class_name: 'Category', optional: true
  belongs_to :user

  validates :title, presence: true, allow_blank: false
  validates :parent, presence: true, allow_blank: true

  scope :ordered_by_title, -> { order('title ASC') }
  scope :ordered_by_active, -> { order('active = true DESC') }
  scope :projects, -> { where(parent: where(title: 'Projects', deletable: false)) }
  scope :active, -> { where(active: true) }
  scope :parents_ordered_by_title, -> { where(parent: nil).order('title ASC') }

  def full_title
    return self.title if self.parent.nil?
    "#{self.parent.title} :: #{self.title}"
  end

  def active?
    self.active
  end

  def inactive?
    active? ? false : true
  end

  def subcategories_notes
    self.subcategories.map{|a| a.inventory_notes}.flatten
  end

  def items_amount
    itcat = self.inventory_items.count || 0
    itsub = self.subcategories.map{|a| a.inventory_items.count}.inject(:+) || 0
    itcat + itsub
  end

  def is_a_project?
    self.parent_id.present? && parent.title == 'Projects'
  end

  private

  def set_slug
    loop do
      self.slug = self.title.parameterize
      break unless Category.where(slug: slug, user: user).exists?
    end
  end

  def protect_unchangeables
    unless self.deletable
      raise ActiveRecord::ReadOnlyRecord
      errors.add(:base, "cannot change #{self.title} category")
    end
  end
end
