require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

before do
  session[:lists] ||= []
  p session
end

helpers do
  def list_completed?(list)
    total_todos_count(list) > 0 && remaining_todos_count(list) == 0
  end

  def remaining_todos_count(list)
    # return 0 if list[:todo].nil?
    list[:todos].count { |todo| !todo[:completed] }
  end

  def list_class(list)
    "complete" if list_completed?(list)
  end

  def todo_list_class(todo)
    "complete" if todo[:completed]
  end

  def total_todos_count(list)
    # return 0 if list[:todos].nil?
    list[:todos].size
  end

  # def sort_lists(&block)
  #   finished = {}
  #   unfinished = {}

  #   session[:lists].each_with_index do |list, index|
  #     if list_completed?(list)
  #       finished[list] = index
  #     else
  #       unfinished[list] = index
  #     end
  #   end
  #   unfinished.merge(finished).each(&block)
  # end

  # def sort_todos(todos)
  #   return nil if todos.nil?
  #   finished, unfinished = todos.partition { |todo| todo[:completed] }

  #   (unfinished + finished).each do |todo|
  #     yield(todo)
  #   end
  # end
# end

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
  list = session[:lists].find { |list| list[:id] == id.to_i }

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
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# render new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end


# create a new list
post "/lists" do
  @lists = session[:lists]
  @list_name = params[:list_name].strip
  error = list_name_error(@list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] <<  { name: @list_name, id: next_element_id(@lists), todos: [] }
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
  if session[:lists].any? { |list| list[:name] == list_name }
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
    @list[:name] = new_name
    session[:success] = "List has been updated"
    redirect "/lists/#{@list_id}"
  end
end

# delete a list
post "/lists/:id/destroy" do
  @list_id = params[:id]
  @list = load_list(@list_id)
  @list_name = @list[:name]
  session[:lists].reject! { |list| list[:id] == @list_id.to_i }

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

def next_element_id(elements)
    max = elements.map { |elem| elem[:id] }.max || 0
    max + 1
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
    @todo_id = next_element_id(@list[:todos])
    @list[:todos] << { id: @todo_id, name: todo_name, completed: false }
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
  @list[:todos] = @list[:todos].reject! do |todo|
    todo[:id] == @todo_id
  end

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
  p is_completed
  todo = @list[:todos].find { |todo| todo[:id] == @todo_id.to_i }
  todo[:completed] = is_completed
  session[:success] = "The todo has been updated"
  redirect "/lists/#{@list_id}"
end

# mark all todos on a list as completed
post "/lists/:list_id/complete" do
  @list_id = params[:list_id]
  @list = load_list(@list_id)
  @list_name = @list[:name]

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been marked complete."
  redirect "/lists/#{@list_id}"
end
