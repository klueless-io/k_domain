class Comment < ActiveRecord::Base
  include ActsAsCommentable::Comment

  belongs_to :commentable, polymorphic: true

  default_scope { order(created_at: :asc) }

  # NOTE: install the acts_as_votable plugin if you
  # want user to vote on the quality of comments.
  #acts_as_voteable

  # NOTE: Comments belong to a user
  belongs_to :user
  belongs_to :tenant



  def send_new_comment_email(host, selected_users)
    # SEND EMAILS TO EACH SELECTED_USER
    to_addrs = []

    selected_users.each do |user|
      to_addrs << test_mode_if_required(user.email) unless user.email.blank?
    end

    return unless to_addrs.count > 0

    send_mail(host, to_addrs, "Print Speak: New Comment on #{commentable.class }: #{commentable.name}")
  end

  def send_mail(host, addresses, email_subject, source_email = "support@printspeak.com")
    Thread.new {
      Email.ses_send(addresses, email_subject, Emails::Comment.new.new_comment(self, user, host), source_email)
      ActiveRecord::Base.clear_active_connections!
    }
  end

  def test_mode_if_required(email_address)
    if Rails.env.production?
      email_address
    else
      "emailtest@printspeak.com"
    end
  end
end
