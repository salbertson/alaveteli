# -*- encoding : utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe AdminRawEmailController do

  describe 'GET show' do

    before do
      @raw_email = FactoryBot.create(:incoming_message).raw_email
    end

    describe 'html version' do

      it 'renders the show template' do
        get :show, params: { :id => @raw_email.id }
      end

      context 'when showing a message with a "From" address in the holding pen' do

        before do
          @public_body = FactoryBot.create(:public_body,
                                           :request_email => 'body@example.uk')
          @info_request = FactoryBot.create(:info_request)
          @invalid_to =
            @info_request.incoming_email.sub(@info_request.id.to_s, 'invalid')
          raw_email_data = <<-EOF.strip_heredoc
          From: bob@example.uk
          To: #{ @invalid_to }
          Subject: Basic Email
          Hello, World
          EOF
          @incoming_message = FactoryBot.create(
            :plain_incoming_message,
            :info_request => InfoRequest.holding_pen_request,
          )
          @incoming_message.raw_email.data = raw_email_data
          @incoming_message.raw_email.save!
          @info_request_event = FactoryBot.create(
            :info_request_event,
            :event_type => 'response',
            :info_request => InfoRequest.holding_pen_request,
            :incoming_message => @incoming_message,
            :params => {:rejected_reason => 'Too dull'}
          )
        end

        it 'assigns public bodies that match the "From" domain' do
          get :show, params: { :id => @incoming_message.raw_email.id }
          expect(assigns[:public_bodies]).to eq [@public_body]
        end

        it 'assigns guessed requests based on the hash' do
          get :show, params: { :id => @incoming_message.raw_email.id }
          guess = InfoRequest::Guess.new(@info_request, @invalid_to, :idhash)
          expect(assigns[:guessed_info_requests]).to eq([guess])
        end

        it 'assigns a reason why the message is in the holding pen' do
          get :show, params: { :id => @incoming_message.raw_email.id }
          expect(assigns[:rejected_reason]).to eq 'Too dull'
        end

        it 'assigns a default reason if no reason is given' do
          @info_request_event.params_yaml = {}.to_yaml
          @info_request_event.save!
          get :show, params: { :id => @incoming_message.raw_email.id }
          expect(assigns[:rejected_reason]).to eq 'unknown reason'
        end

      end

    end

    describe 'text version' do

      it 'sends the email as an RFC-822 attachment' do
        get :show, params: { :id => @raw_email.id, :format => 'eml' }
        expect(response.content_type).to eq('message/rfc822')
        expect(response.body).to eq(@raw_email.data)
      end
    end

  end

end
