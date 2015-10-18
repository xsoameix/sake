require 'pathname'
require 'rest-client'
require 'colorize'
require 'filesize'
require 'open-uri'
require 'active_support/core_ext/string'

class Store

  def initialize
    config = JSON.parse(File.read ARGV[0])
    @accounts = config['stores'].flat_map do |store|
      klass = Store.const_get(store['location'])
      store['accounts'].map do |acct|
        klass.new acct
      end
    end
  end

  def login; @accounts.each &:login end

  def info
    @accounts.each &:info
  end

  def ls(path = '/')
    path = Pathname.new path
    @accounts.map do |acct|
      acct.ls path
    end
  end

  def mkdir(path)
    path = Pathname.new path
    @accounts.each do |acct|
      acct.mkdir path
    end
  end

  def rmdir(path)
    path = Pathname.new path
    @accounts.each do |acct|
      acct.rmdir path
    end
  end

  def rmdir_f(path)
    path = Pathname.new path
    @accounts.each do |acct|
      acct.rmdir_f path
    end
  end

  # TODO: choose suitable store
  def put(path, pwd)
    path = Pathname.new path
    pwd = Pathname.new pwd
    @accounts.each do |acct|
      acct.put path, pwd
    end
  end

  # TODO: find store
  def get(path, pwd)
    path = Pathname.new path
    pwd = Pathname.new pwd
    @accounts.each do |acct|
      acct.get path, pwd
    end
  end

  # TODO: find store
  def rm(path)
    path = Pathname.new path
    @accounts.each do |acct|
      acct.rm path
    end
  end

  # TODO: find store
  def rm_f(path)
    path = Pathname.new path
    @accounts.each do |acct|
      acct.rm_f path
    end
  end

  # TODO: find store
  def trash_rm(path)
    path = Pathname.new path
    @accounts.each do |acct|
      acct.trash_rm path
    end
  end

  # TODO: one store
  def trash_rm_all
    @accounts.each do |acct|
      acct.trash_rm_all
    end
  end
end

require './mediafire'
