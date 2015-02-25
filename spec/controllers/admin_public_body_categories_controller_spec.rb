require 'spec_helper'

describe AdminPublicBodyCategoriesController do

    describe :index do

        it 'responds successfully' do
            get :index
            expect(response).to be_success
        end

        it 'uses the current locale by default' do
            get :index
            expect(assigns(:locale)).to eq(I18n.locale.to_s)
        end

        it 'sets the locale if the show_locale param is passed' do
            get :index, :show_locale => 'es'
            expect(assigns(:locale)).to eq('es')
        end

        it 'finds all category headings' do
            PublicBodyHeading.destroy_all

            headings = [FactoryGirl.create(:public_body_heading),
                        FactoryGirl.create(:public_body_heading)]

            get :index

            expect(assigns(:category_headings)).to eq(headings)
        end

        it 'finds all categories without their headings' do
            PublicBodyHeading.destroy_all
            PublicBodyCategory.destroy_all

            without_heading = FactoryGirl.create(:public_body_category)

            heading = FactoryGirl.create(:public_body_heading)
            with_heading = FactoryGirl.create(:public_body_category)
            PublicBodyCategoryLink.create!(:public_body_heading_id => heading.id,
                                           :public_body_category_id => with_heading.id)


            get :index
            expect(assigns(:without_heading)).to eq([without_heading])
        end

        it 'renders the index template' do
            get :index
            expect(response).to render_template('index')
        end

    end

    describe :new do

        it 'responds successfully' do
            get :new
            expect(response).to be_success
        end

        it 'builds a new PublicBodyCategory' do
            get :new
            expect(assigns(:category)).to be_new_record
        end

       it 'builds new translations for all locales' do
           get :new

           translations = assigns(:category).translations.map{ |t| t.locale.to_s }.sort
           available = I18n.available_locales.map{ |l| l.to_s }.sort

           expect(translations).to eq(available)
       end

       it 'renders the new template' do
           get :new
           expect(response).to render_template('new')
       end

    end

    context 'when creating a public body category' do
        it "creates a new public body category in one locale" do
            n = PublicBodyCategory.count
            post :create, {
                :public_body_category => {
                    :title => 'New Category',
                    :category_tag => 'new_test_category',
                    :description => 'New category for testing stuff'
                 }
            }
            PublicBodyCategory.count.should == n + 1

            category = PublicBodyCategory.find_by_title("New Category")
            response.should redirect_to(admin_categories_path)
        end

        it "saves the public body category's heading associations" do
            heading = FactoryGirl.create(:public_body_heading)
            category_attributes = FactoryGirl.attributes_for(:public_body_category)
            post :create, {
                    :public_body_category => category_attributes,
                    :headings => {"heading_#{heading.id}" => heading.id}
            }
            request.flash[:notice].should include('successful')
            category = PublicBodyCategory.find_by_title(category_attributes[:title])
            category.public_body_headings.should == [heading]
        end

        it 'creates a new public body category with multiple locales' do
            n = PublicBodyCategory.count
            post :create, {
                :public_body_category => {
                    :title => 'New Category',
                    :category_tag => 'new_test_category',
                    :description => 'New category for testing stuff',
                    :translations_attributes => {
                        'es' => { :locale => "es",
                                  :title => "Mi Nuevo Category" }
                    }
                }
            }
            PublicBodyCategory.count.should == n + 1

            category = PublicBodyCategory.find_by_title("New Category")
            #category.translations.map {|t| t.locale.to_s}.sort.should == ["en", "es"]
            I18n.with_locale(:en) do
                category.title.should == "New Category"
            end
            I18n.with_locale(:es) do
                category.title.should == "Mi Nuevo Category"
            end

            response.should redirect_to(admin_categories_path)
        end

        it "renders the form if creating the record was unsuccessful" do
            post :create, :public_body_category => { :title => '' }
            expect(response).to render_template('new')
        end

    end

    describe :edit do

        before do
            @category = FactoryGirl.create(:public_body_category)
            I18n.with_locale('es') do
                @category.title = 'Los category'
                @category.save!
            end
        end

        it 'responds successfully' do
            get :edit, :id => @category.id
            expect(response).to be_success
        end

        it 'finds the requested category' do
            get :edit, :id => @category.id
            expect(assigns[:category]).to eq(@category)
        end

        it 'builds new translations if the body does not already have a translation in the specified locale' do
            get :edit, :id => @category.id
            expect(assigns[:category].translations.map(&:locale)).to include(:fr)
        end

        it 'finds the public bodies tagged with the category tag' do
            # FIXME: I wanted to call PublicBody.destroy_all here so that we
            # have a known DB state, but the constraints were preventing the
            # deletion of the fixture data
            FactoryGirl.create(:public_body, :tag_string => 'wont_be_found')

            category = FactoryGirl.create(:public_body_category, :category_tag => 'spec')          
            expected_bodies = [FactoryGirl.create(:public_body, :tag_string => 'spec'),
                               FactoryGirl.create(:public_body, :tag_string => 'spec')]

            get :edit, :id => category.id

            expect(assigns(:tagged_public_bodies)).to eq(expected_bodies)
        end

        it 'renders the edit template' do
            get :edit, :id => @category.id
            expect(assigns[:category]).to render_template('edit')
        end

    end

    context 'when updating a public body category' do

        before do
            @heading = FactoryGirl.create(:public_body_heading)
            @category = FactoryGirl.create(:public_body_category)
            link = FactoryGirl.create(:public_body_category_link,
                                      :public_body_category => @category,
                                      :public_body_heading => @heading,
                                      :category_display_order => 0)
            @tag = @category.category_tag
            I18n.with_locale('es') do
                @category.title = 'Los category'
                @category.save!
            end
        end

        render_views

        it "saves edits to a public body category" do
            post :update, { :id => @category.id,
                            :public_body_category => { :title => "Renamed" } }
            request.flash[:notice].should include('successful')
            pbc = PublicBodyCategory.find(@category.id)
            pbc.title.should == "Renamed"
        end

        it "saves edits to a public body category's heading associations" do
            @category.public_body_headings.should == [@heading]
            heading = FactoryGirl.create(:public_body_heading)
            post :update, { :id => @category.id,
                            :public_body_category => { :title => "Renamed" },
                            :headings => {"heading_#{heading.id}" => heading.id} }
            request.flash[:notice].should include('successful')
            pbc = PublicBodyCategory.find(@category.id)
            pbc.public_body_headings.should == [heading]
        end

        it "saves edits to a public body category in another locale" do
            I18n.with_locale(:es) do
                @category.title.should == 'Los category'
                post :update, {
                    :id => @category.id,
                    :public_body_category => {
                        :title => "Category",
                        :translations_attributes => {
                            'es' => { :locale => "es",
                                      :title => "Renamed" }
                            }
                        }
                    }
                request.flash[:notice].should include('successful')
            end

            pbc = PublicBodyCategory.find(@category.id)
            I18n.with_locale(:es) do
               pbc.title.should == "Renamed"
            end
            I18n.with_locale(:en) do
               pbc.title.should == "Category"
            end
        end

        it 'adds a new translation' do
             @category.translation_for(:es).destroy
             @category.reload

             put :update, {
                 :id => @category.id,
                 :public_body_category => {
                     :title => @category.title,
                     :description => @category.description,
                     :translations_attributes => {
                         'es' => { :locale => "es",
                                   :title => "Example Public Body Category ES",
                                   :description => @category.description }
                     }
                 }
             }

             request.flash[:notice].should include('successful')

             pbc = PublicBodyCategory.find(@category.id)

             I18n.with_locale(:es) do
                expect(pbc.title).to eq('Example Public Body Category ES')
             end
         end

         it 'adds new translations' do
             @category.translation_for(:es).destroy
             @category.reload

             post :update, {
                 :id => @category.id,
                 :public_body_category => {
                     :title => @category.title,
                     :description => @category.description,
                     :translations_attributes => {
                         'es' => { :locale => "es",
                                   :title => "Example Public Body Category ES",
                                   :description => @category.description },
                         'fr' => { :locale => "fr",
                                   :title => "Example Public Body Category FR",
                                   :description => @category.description }
                     }
                 }
             }

             request.flash[:notice].should include('successful')

             pbc = PublicBodyCategory.find(@category.id)

             I18n.with_locale(:es) do
                expect(pbc.title).to eq('Example Public Body Category ES')
             end
             I18n.with_locale(:fr) do
                expect(pbc.title).to eq('Example Public Body Category FR')
             end
         end

         it 'updates an existing translation and adds a third translation' do
             post :update, {
                 :id => @category.id,
                 :public_body_category => {
                     :title => @category.title,
                     :description => @category.description,
                     :translations_attributes => {
                         # Update existing translation
                         'es' => { :locale => "es",
                                   :title => "Renamed Example Public Body Category ES",
                                   :description => @category.description },
                         # Add new translation
                         'fr' => { :locale => "fr",
                                   :title => "Example Public Body Category FR",
                                   :description => @category.description }
                     }
                 }
             }

             request.flash[:notice].should include('successful')

             pbc = PublicBodyCategory.find(@category.id)

             I18n.with_locale(:es) do
                expect(pbc.title).to eq('Renamed Example Public Body Category ES')
             end
             I18n.with_locale(:fr) do
                expect(pbc.title).to eq('Example Public Body Category FR')
             end
         end

        it "does not save edits to category_tag if the category has associated bodies" do
            body = FactoryGirl.create(:public_body, :tag_string => @tag)
            post :update, { :id => @category.id,
                            :public_body_category => { :category_tag => "renamed" } }
                            
            msg = "There are authorities associated with this category, so the tag can't be renamed"
            request.flash[:error].should == msg
            pbc = PublicBodyCategory.find(@category.id)
            pbc.category_tag.should == @tag
        end


        it "save edits to category_tag if the category has no associated bodies" do
            category = PublicBodyCategory.create(:title => "Empty Category", :category_tag => "empty", :description => "-")
            post :update, { :id => category.id,
                            :public_body_category => { :category_tag => "renamed" } }
            request.flash[:notice].should include('success')
            pbc = PublicBodyCategory.find(category.id)
            pbc.category_tag.should == "renamed"
        end

        it "redirects to the edit page after a successful update" do
            post :update, { :id => @category.id,
                            :public_body_category => { :title => "Renamed" } }

            expect(response).to redirect_to(edit_admin_category_path(@category))
        end

        it "re-renders the edit form after an unsuccessful update" do
            post :update, { :id => @category.id,
                            :public_body_category => { :title => '' } }

            expect(response).to render_template('edit')
        end

    end

    describe :destroy do

        it 'uses the current locale by default' do
            category = FactoryGirl.create(:public_body_category)
            post :destroy, :id => category.id
            expect(assigns(:locale)).to eq(I18n.locale.to_s)
        end

        it 'sets the locale if the show_locale param is passed' do
            category = FactoryGirl.create(:public_body_category)
            post :destroy, :id => category.id, :show_locale => 'es'
            expect(assigns(:locale)).to eq('es')
        end

        it 'destroys empty public body categories' do
            PublicBodyCategory.destroy_all

            category = FactoryGirl.create(:public_body_category)
            
            expect{
              post :destroy, :id => category.id
            }.to change{ PublicBodyCategory.count }.from(1).to(0)
        end

        it 'destroys non-empty public body categories' do
            PublicBodyCategory.destroy_all

            # FIXME: Couldn't create the PublicBodyCategory with a Factory
            # because #authorities= doesn't exist?
            # undefined method `authorities=' for 
            # #<PublicBodyCategory:0x7f55cbb84f70>
            authority = FactoryGirl.create(:public_body)
            category = PublicBodyCategory.create(:title => "In-Use Category",
                                                 :category_tag => "empty",
                                                 :description => "-",
                                                 :authorities => [authority])

            expect{
              post :destroy, :id => category.id
            }.to change{ PublicBodyCategory.count }.from(1).to(0)
        end

        it 'notifies the admin that the category was destroyed' do
            category = FactoryGirl.create(:public_body_category)
            post :destroy, :id => category.id
            expect(flash[:notice]).to eq('Category was successfully destroyed.')
        end

        it 'redirects to the categories index' do
            category = FactoryGirl.create(:public_body_category)
            post :destroy, :id => category.id
            expect(response).to redirect_to(admin_categories_path)
        end

    end
end
