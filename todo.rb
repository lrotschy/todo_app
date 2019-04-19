require "sinatra"
require "tilt/erubis"
require "sinatra/content_for"
require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

before do
  @storage = DatabasePersistence.new(logger)
end

helpers do
  def list_completed?(list)
    total_todos_count(list) > 0 && remaining_todos_count(list) == 0
  end

  def remaining_todos_count(list)
    return 0 if list[:todos].nil?
    list[:todos].count { |todo| todo[:completed] == false }
  end

  def list_class(list)
    "complete" if list_completed?(list)
  end

  def todo_list_class(todo)
    "complete" if todo[:completed]
  end

  def total_todos_count(list)
    return 0 if list[:todos].nil?
    list[:todos].size
  end

  def sort_lists(lists, &block)
    finished, unfinished = lists.partition { |list| list_completed?(list) }
    unfinished.each(&block)
    finished.each(&block)
  end

  def sort_todos(todos, &block)
    finished, unfinished = todos.partition { |todo| todo[:completed] }
    unfinished.each(&block)
    finished.each(&block)
  end

  def load_list(id)
    list = @storage.find_list(id)
    return list if list

    session[:error] = "The specified list was not found"
    redirect "/lists"
    halt
  end
end


get "/" do
  redirect "/lists"
end

# view list of lists
get "/lists" do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# render new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# create a new list
post "/lists" do
  @lists = @storage.all_lists

  @list_name = params[:list_name].strip
  error = list_name_error(@list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_list(@list_name)
    session[:success] = "New list created"

    redirect "/lists"
  end
end

# view a single list
get "/lists/:id" do
  @list_id = params[:id]
  @list = load_list(@list_id)
  @todos = @list[:todos]
  @list_name = @list[:name]
  erb :list, layout: :layout
end

# edit an existing list
get "/lists/edit/:id" do
  @list_id = params[:id]
  @list = load_list(@list_id)
  @list_name = @list[:name]
  erb :edit_list, layout: :layout
end

# return error message if list name is invalid; nil if valid
def list_name_error(list_name)
  if @storage.all_lists.any? { |list| list[:name] == list_name }
    "List name must be unique."
  elsif !(1..100).cover? list_name.size
    "List name must be 1 - 100 characters."
  end
end

# submit name change for existing list
post "/lists/:id" do
  @list_id = params[:id]
  @list = load_list(@list_id)
  new_name = params[:new_list_name].strip
  error = list_name_error(new_name)
  if error
    puts error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.rename_list(@list_id, new_name)
    session[:success] = "List has been updated"
    redirect "/lists/#{@list_id}"
  end
end

# delete a list
post "/lists/:id/destroy" do
  @list_id = params[:id]
  @list = load_list(@list_id)
  @list_name = @list[:name]
  @storage.delete_list(@list_id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    # ajax
    "/lists"
  else
    session[:success] = "List Deleted"
    redirect "/lists"
  end
end

# return error message if todo is invalid; nil if valid
def error_for_todo(todo_name)
  if !(1..100).cover? todo_name.size
    "Todo name must be 1 - 100 characters."
  end
end

# add a todo to a list
post "/lists/:id/todos" do
  @list_id = params[:id]
  @list = load_list(@list_id)
  @list_name = @list[:name]
  todo_name = params[:todo].strip

  error = error_for_todo(todo_name)

  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.add_todo(@list_id, todo_name)
    session[:success] = "Todo item successfully added"
    redirect "/lists/#{@list_id}"
  end
end

# delete a todo item from a list
post "/lists/:list_id/todos/:todo_id/destroy" do
  @list_id = params[:list_id]
  @list = load_list(@list_id)
  @list_name = @list[:name]
  @todo_id = params[:todo_id]
  @storage.delete_todo_item(@list_id, @todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# update completed status of todo
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id]
  @list = load_list(@list_id)
  @list_name = @list[:name]
  @todo_id = params[:todo_id]
  is_completed = params[:completed] == 'true'
  @storage.update_completed_status(@list_id, @todo_id, is_completed)
  session[:success] = "The todo has been updated"
  redirect "/lists/#{@list_id}"
end

# mark all todos on a list as completed
post "/lists/:list_id/complete" do
  @list_id = params[:list_id]
  @list = load_list(@list_id)
  @list_name = @list[:name]

  @storage.mark_all_completed(@list_id)

  session[:success] = "All todos have been marked complete."
  redirect "/lists/#{@list_id}"
end
