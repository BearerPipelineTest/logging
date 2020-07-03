
# only load this class if we have the syslog library
# Windows does not have syslog
#
if HAVE_SYSLOG

module Logging::Appenders

  # Accessor / Factory for the Syslog appender.
  #
  def self.syslog( *args )
    fail ArgumentError, '::Logging::Appenders::Syslog needs a name as first argument.' if args.empty?
    ::Logging::Appenders::Syslog.new(*args)
  end

  # This class provides an Appender that can write to the UNIX syslog
  # daemon.
  #
  class Syslog < ::Logging::Appender
    include ::Syslog::Constants

    # call-seq:
    #    Syslog.new( name, opts = {} )
    #
    # Create an appender that will log messages to the system message
    # logger. The message is then written to the system console, log files,
    # logged-in users, or forwarded to other machines as appropriate. The
    # options that can be used to configure the appender are as follows:
    #
    #    :ident     => identifier string (name is used by default)
    #    :logopt    => options used when opening the connection
    #    :facility  => the syslog facility to use
    #
    # The parameter :ident is a string that will be prepended to every
    # message. The :logopt argument is a bit field specifying logging
    # options, which is formed by OR'ing one or more of the following
    # values:
    #
    #    LOG_CONS      If syslog() cannot pass the message to syslogd(8) it
    #                  wil attempt to write the message to the console
    #                  ('/dev/console').
    #
    #    LOG_NDELAY    Open the connection to syslogd(8) immediately. Normally
    #                  the open is delayed until the first message is logged.
    #                  Useful for programs that need to manage the order in
    #                  which file descriptors are allocated.
    #
    #    LOG_PERROR    Write the message to standard error output as well to
    #                  the system log.  Not available on Solaris.
    #
    #    LOG_PID       Log the process id with each message: useful for
    #                  identifying instantiations of daemons.
    #
    # The :facility parameter encodes a default facility to be assigned to
    # all messages that do not have an explicit facility encoded:
    #
    #    LOG_AUTH      The authorization system: login(1), su(1), getty(8),
    #                  etc.
    #
    #    LOG_AUTHPRIV  The same as LOG_AUTH, but logged to a file readable
    #                  only by selected individuals.
    #
    #    LOG_CONSOLE   Messages written to /dev/console by the kernel console
    #                  output driver.
    #
    #    LOG_CRON      The cron daemon: cron(8).
    #
    #    LOG_DAEMON    System daemons, such as routed(8), that are not
    #                  provided for explicitly by other facilities.
    #
    #    LOG_FTP       The file transfer protocol daemons: ftpd(8), tftpd(8).
    #
    #    LOG_KERN      Messages generated by the kernel. These cannot be
    #                  generated by any user processes.
    #
    #    LOG_LPR       The line printer spooling system: lpr(1), lpc(8),
    #                  lpd(8), etc.
    #
    #    LOG_MAIL      The mail system.
    #
    #    LOG_NEWS      The network news system.
    #
    #    LOG_SECURITY  Security subsystems, such as ipfw(4).
    #
    #    LOG_SYSLOG    Messages generated internally by syslogd(8).
    #
    #    LOG_USER      Messages generated by random user processes. This is
    #                  the default facility identifier if none is specified.
    #
    #    LOG_UUCP      The uucp system.
    #
    #    LOG_LOCAL0    Reserved for local use. Similarly for LOG_LOCAL1
    #                  through LOG_LOCAL7.
    #
    def initialize( name, opts = {} )
      @ident = opts.fetch(:ident, name)
      @logopt = Integer(opts.fetch(:logopt, (LOG_PID | LOG_CONS)))
      @facility = Integer(opts.fetch(:facility, LOG_USER))
      @syslog = ::Syslog.open(@ident, @logopt, @facility)

      # provides a mapping from the default Logging levels
      # to the syslog levels
      @map = [LOG_DEBUG, LOG_INFO, LOG_WARNING, LOG_ERR, LOG_CRIT]

      map = opts.fetch(:map, nil)
      self.map = map unless map.nil?

      super
    end

    # call-seq:
    #    map = { logging_levels => syslog_levels }
    #
    # Configure the mapping from the Logging levels to the syslog levels.
    # This is needed in order to log events at the proper syslog level.
    #
    # Without any configuration, the following mapping will be used:
    #
    #    :debug  =>  LOG_DEBUG
    #    :info   =>  LOG_INFO
    #    :warn   =>  LOG_WARNING
    #    :error  =>  LOG_ERR
    #    :fatal  =>  LOG_CRIT
    #
    def map=( levels )
      map = []
      levels.keys.each do |lvl|
        num = ::Logging.level_num(lvl)
        map[num] = syslog_level_num(levels[lvl])
      end
      @map = map
    end

    # call-seq:
    #    close
    #
    # Closes the connection to the syslog facility.
    #
    def close( footer = true )
      super
      @syslog.close if @syslog.opened?
      self
    end

    # call-seq:
    #    closed?    => true or false
    #
    # Queries the connection to the syslog facility and returns +true+ if
    # the connection is closed.
    #
    def closed?
      !@syslog.opened?
    end

    # Reopen the connection to the underlying logging destination. If the
    # connection is currently closed then it will be opened. If the connection
    # is currently open then it will be closed and immediately opened.
    #
    def reopen
      sync {
        if @syslog.opened?
          flush
          @syslog.close
        end
        @syslog = ::Syslog.open(@ident, @logopt, @facility)
      }
      super
      self
    end


    private

    # call-seq:
    #    write( event )
    #
    # Write the given _event_ to the syslog facility. The log event will be
    # processed through the Layout associated with this appender. The message
    # will be logged at the level specified by the event.
    #
    def write( event )
      pri = LOG_DEBUG
      message = if event.instance_of?(::Logging::LogEvent)
          pri = @map[event.level]
          @layout.format(event)
        else
          event.to_s
        end
      return if message.empty?

      sync { @syslog.log(pri, '%s', message) }
      self
    end

    # call-seq:
    #    syslog_level_num( level )    => integer
    #
    # Takes the given _level_ as a string, symbol, or integer and returns
    # the corresponding syslog level number.
    #
    def syslog_level_num( level )
      case level
      when Integer; level
      when String, Symbol
        level = level.to_s.upcase
        self.class.const_get level
      else
        raise ArgumentError, "unknown level '#{level}'"
      end
    end

  end  # Syslog
end  # Logging::Appenders
end  # HAVE_SYSLOG
