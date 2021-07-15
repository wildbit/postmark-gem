require 'spec_helper'

describe Postmark::HashHelper do
  describe '.to_postmark' do
    context 'single level hash objects to convert' do
      let(:source) { { :from => "support@postmarkapp.com", :reply_to => "contact@wildbit.com" } }
      let(:target) { { "From" => "support@postmarkapp.com", "ReplyTo" => "contact@wildbit.com" } }

      it 'convert Hash keys to Postmark format' do
        expect(subject.to_postmark(source)).to eq target
      end

      it 'acts idempotentely' do
        subject.to_postmark(target)
        expect(subject.to_postmark(target)).to eq target
      end
    end

    context 'multi level hash objects to convert' do
      it 'convert Hash keys to Postmark format - one sub level hash' do
        source = { :id => 'custom-id',
                   :name => 'Some Stream Name 3',
                   :message_stream_type => 'Broadcasts',
                   :subscription_management_configuration => { :unsubscribe_handling_type => 'Custom' } }

        target = { 'Id' => 'custom-id',
                   'Name' => 'Some Stream Name 3',
                   'MessageStreamType' => 'Broadcasts',
                   'SubscriptionManagementConfiguration' => { 'UnsubscribeHandlingType' => 'Custom' } }

        expect(subject.to_postmark(source)).to eq target
      end

      context 'multiple sub levels hash to convert' do
        let(:ruby_formatted_hash) {
          { :id => 'custom-id',
            :top => {
              :level_one => {
                :level_two => {
                  :level_three => [
                    { :one_level_three_type => 'Value1' },
                    { :second_level_three_type => 'Value2' }
                  ]
                }
              }
            }
          }
        }

        let(:postmark_formatted_hash) {
          { 'Id' => 'custom-id',
            'Top' => {
              'LevelOne' => {
                'LevelTwo' => {
                  'LevelThree' => [
                    { 'OneLevelThreeType' => 'Value1' },
                    { 'SecondLevelThreeType' => 'Value2' }
                  ]
                }
              }
            }
          }
        }

        it 'default options' do
          expect(subject.to_postmark(ruby_formatted_hash)).to eq postmark_formatted_hash
        end

        it 'options - deep conversion off' do
          postmark_formatted_hash = { 'Id' => 'custom-id',
                                      'Top' => {
                                        :level_one => {
                                          :level_two => {
                                            :level_three =>
                                              [
                                                { :one_level_three_type => 'Value1' },
                                                { :second_level_three_type => 'Value2' }
                                              ]
                                          }
                                        }
                                      }
          }

          expect(subject.to_postmark(ruby_formatted_hash, :deep_conversion => false)).to eq postmark_formatted_hash
        end

        it 'options - keys_to_skip' do
          postmark_formatted_hash = { 'Id' => 'custom-id',
                                      'Top' => {
                                        'LevelOne' => {
                                          :level_two => {
                                            :level_three => [
                                              { :one_level_three_type => 'Value1' },
                                              { :second_level_three_type => 'Value2' }
                                            ]
                                          }
                                        }
                                      }
          }

          expect(subject.to_postmark(ruby_formatted_hash, :keys_to_skip => [:level_one])).to eq postmark_formatted_hash
        end

        it 'options - keys_to_skip - multiple' do
          ruby_formatted_hash = {
            :id => 'custom-id',
            :one_sub_level => {
              :level_one => 'Value1'
            },
            :second_sub_level => {
              :level_one => 'Value1'
            },
            :sub_levels => {
              :level_one => {
                :level_two => [
                  { :level_two_key_one => 'LevelTwoValueOne' },
                  { :level_two_key_two => 'LevelTwoValueTwo' }
                ]
              }
            }
          }

          postmark_formatted_hash = {
            'Id' => 'custom-id',
            'OneSubLevel' => {
              :level_one => 'Value1'
            },
            'SecondSubLevel' => {
              'LevelOne' => 'Value1'
            },
            'SubLevels' => {
              :level_one => {
                :level_two => [
                  { :level_two_key_one => 'LevelTwoValueOne' },
                  { :level_two_key_two => 'LevelTwoValueTwo' }
                ]
              }
            }
          }

          expect(subject.to_postmark(ruby_formatted_hash,
                                     :keys_to_skip => [:one_sub_level, :sub_levels])).to eq postmark_formatted_hash
        end
      end
    end
  end

  describe '.to_ruby' do

    it 'convert with compatibility mode' do
      source =  { 'From' => 'support@postmarkapp.com', 'ReplyTo' => 'contact@wildbit.com' }
      target = { :from => 'support@postmarkapp.com', :reply_to => 'contact@wildbit.com' }

      expect(subject.to_ruby(source, true)).to eq source.merge(target)
    end

    context 'single level hash objects to convert' do
      let(:source) { { "From" => "support@postmarkapp.com", "ReplyTo" => "contact@wildbit.com" } }
      let(:target) { { :from => "support@postmarkapp.com", :reply_to => "contact@wildbit.com" } }

      it 'convert Hash keys to Ruby format' do
        expect(subject.to_ruby(source)).to eq target
      end

      it 'has compatible mode' do
        expect(subject.to_ruby(source, true)).to eq target.merge(source)
      end

      it 'acts idempotentely' do
        subject.to_ruby(target)
        expect(subject.to_ruby(target)).to eq target
      end
    end

    context 'multi level hash objects to convert' do
      it 'convert Hash keys to Ruby format - one sub level hash' do
        target = { :id => 'custom-id',
                   :name => 'Some Stream Name 3',
                   :message_stream_type => 'Broadcasts',
                   :subscription_management_configuration => { :unsubscribe_handling_type => 'Custom' } }

        source = { 'Id' => 'custom-id',
                   'Name' => 'Some Stream Name 3',
                   'MessageStreamType' => 'Broadcasts',
                   'SubscriptionManagementConfiguration' => { 'UnsubscribeHandlingType' => 'Custom' } }

        expect(subject.to_ruby(source)).to eq target
      end

      context 'multiple sub levels hash to convert' do
        let(:ruby_formatted_hash) {
          { :id => 'custom-id',
            :top => {
              :level_one => {
                :level_two => {
                  :level_three => [
                    { :one_level_three_type => 'Value1' },
                    { :second_level_three_type => 'Value2' }
                  ]
                }
              }
            }
          }
        }

        let(:postmark_formatted_hash) {
          { 'Id' => 'custom-id',
            'Top' => {
              'LevelOne' => {
                'LevelTwo' => {
                  'LevelThree' => [
                    { 'OneLevelThreeType' => 'Value1' },
                    { 'SecondLevelThreeType' => 'Value2' }
                  ]
                }
              }
            }
          }
        }

        it 'default options' do
          expect(subject.to_ruby(postmark_formatted_hash)).to eq ruby_formatted_hash
        end

        it 'options - deep conversion off' do
          ruby_formatted_hash = { :id => 'custom-id',
                                  :top => {
                                    'LevelOne' => {
                                      'LevelTwo' => {
                                       'LevelThree' => [
                                         { 'OneLevelThreeType' => 'Value1' },
                                         { 'SecondLevelThreeType' => 'Value2' }
                                       ]
                                     }
                                   }
                                 }
                                }

          expect(subject.to_ruby(postmark_formatted_hash, false , :deep_conversion => false)).to eq ruby_formatted_hash
        end

        it 'options - keys_to_skip' do
          ruby_formatted_hash = { :id => 'custom-id',
                                  :top => {
                                    :level_one => {
                                      'LevelTwo' => {
                                        'LevelThree' => [
                                          { 'OneLevelThreeType' => 'Value1' },
                                          { 'SecondLevelThreeType' => 'Value2' }
                                        ]
                                      }
                                    }
                                  }
          }

          expect(subject.to_ruby(postmark_formatted_hash, false,
                                 :keys_to_skip => ['LevelOne'])).to eq ruby_formatted_hash
        end

        it 'options - keys_to_skip - multiple' do
          postmark_formatted_hash = {
            'Id' => 'custom-id',
            'OneSubLevel' => {
              'LevelOne' => 'Value1'
            },
            'SecondSubLevel' => {
              'LevelOne' => 'Value1'
            },
            'SubLevels' => {
              'LevelOne' => {
                'LevelTwo' => [
                  { 'LevelTwoKeyOne' => 'LevelTwoValueOne' },
                  { 'LevelTwoKeyTwo' => 'LevelTwoValueTwo' }
                ]
              }
            }
          }

          ruby_formatted_hash = {
            :id => 'custom-id',
            :one_sub_level => {
              'LevelOne' => 'Value1'
            },
            :second_sub_level => {
              :level_one => 'Value1'
            },
            :sub_levels => {
              'LevelOne' => {
                'LevelTwo' => [
                  { 'LevelTwoKeyOne' => 'LevelTwoValueOne' },
                  { 'LevelTwoKeyTwo' => 'LevelTwoValueTwo' }
                ]
              }
            }
          }

          expect(subject.to_ruby(postmark_formatted_hash, false,
                                 :keys_to_skip => ['OneSubLevel', 'SubLevels'])).to eq ruby_formatted_hash
        end
      end
    end
  end
end