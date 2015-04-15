Note to self

Create an account at https://rubygems.org/

```bash
git clone git@github.com:OAuth3/ruby-oauth3-gem.git
gem build oauth3.gemspec
gem push oauth3-1.0.0.gem
  email: john.doe@gmail.com
  password: ******
```

How to unpublish a bad version 

```bash
gem yank oauth3 -v 1.0.4
```

And always remember "You're not going to run out of gem versions, just push a new one." - http://help.rubygems.org/kb/gemcutter/removing-a-published-rubygem
