.PHONY: install test

install:
	bundle install

test:
	ruby test_data.rb

gen:
	ruby stations_for_cpp_on_rails.rb
