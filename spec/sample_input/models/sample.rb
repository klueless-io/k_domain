# frozen_string_literal: true
class Sample < ActiveRecord::Base
  extend RailsUpgrade

  default_scope { where(deleted: false) }

  scope :has_geo, -> { where.not(longitude: nil, latitude: nil) }

  scope :has_address, lambda {
    where.not(address: nil)
  }

  belongs_to :app_user

  belongs_to :tenant, **belongs_to_required

  belongs_to :user, class_name: 'User', foreign_key: 'id', primary_key: 'sales_user_id'

  has_one :user, class_name: 'User', foreign_key: 'id', primary_key: 'sales_user_id'

  has_many :user, class_name: 'User', foreign_key: 'id', primary_key: 'sales_user_id'

  has_many :tasks, as: :taskable

  has_many :messages, class_name: 'CampaignMessage', dependent: :destroy
  has_many :trackers, through: :messages
  has_many :hits, through: :trackers
  has_many :orders, inverse_of: :company

  has_and_belongs_to_many :trackers, -> { uniq }
  has_and_belongs_to_many :contact_lists, -> { uniq }, autosave: true

  validate :ensure_valid_financial_year, on: :create
  validate :name_must_be_unique, :name_must_not_be_in_global
  validate :check_email_valid

  validates :user, presence: { message: 'must exist' }
  validates :tenant, presence: { message: 'must exist' } if rails4?
  validates :first_name, presence: { message: 'First Name is required.' }, on: :create
  validates :email, format: /\A[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,6}\z/i
  validates :password, length: { minimum: 8, message: '8+ characters' }, unless: :skip_password_validation

  # class methods
  def self.class_method1
  end

  def self.class_method2(was, here)
  end

  def self.class_method3(key: 1, another_key: nil)
  end

  # public methods
  def public_method1
  end

  def public_method2(was, here)
  end

  def public_method3(key: 1, another_key: nil)
  end

  private

  # private methods
  def some_private_method
  end

  def some_method(was, here)
  end

  def some_method(key: 1, another_key: nil)
  end
end

# shops
#
# id                                       bigint
# app_user_id                              integer
# name                                     text
# address                                  text
# longitude                                float
# latitude                                 float
