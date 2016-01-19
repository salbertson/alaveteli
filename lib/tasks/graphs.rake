# -*- encoding : utf-8 -*-

require File.join(File.dirname(__FILE__), '../graphs')

namespace :graphs do
  include Graphs

  task :generate_user_use_graph => :environment do
    # set the local font path for the current task
    ENV["GDFONTPATH"] = "/usr/share/fonts/truetype/ttf-bitstream-vera"

    active_users = "SELECT DATE(created_at), COUNT(distinct user_id) " \
                   "FROM info_requests GROUP BY DATE(created_at) " \
                   "ORDER BY DATE(created_at)"

    confirmed_users = "SELECT DATE(created_at), COUNT(*) FROM users " \
                      "WHERE email_confirmed = 't' " \
                      "GROUP BY DATE(created_at) " \
                      "ORDER BY DATE(created_at)"

    # here be database-specific dragons...
    # this uses a window function which is not supported by MySQL, but
    # is reportedly available in MariaDB from 10.2 onward (and Postgres 9.1+)
    aggregate_signups = "SELECT DATE(created_at), COUNT(*), SUM(count(*)) " \
                        "OVER (ORDER BY DATE(created_at)) " \
                        "FROM users GROUP BY DATE(created_at)"

    Gnuplot.open(false) do |gp|
      Gnuplot::Plot.new(gp) do |plot|
        plot.terminal("png font 'Vera.ttf' 9 size 1200,400")
        plot.output(File.expand_path("public/foi-user-use.png", Rails.root))

        #general settings
        plot.unset(:border)
        plot.unset(:arrow)
        plot.key("left")
        plot.tics("out")

        # x-axis
        plot.xdata("time")
        plot.set('timefmt "%Y-%m-%d"')
        plot.set('format x "%d %b %Y"')
        plot.set("xtics nomirror")

        # primary y-axis
        plot.set("ytics nomirror")
        plot.ylabel("number of users on the calendar day")

        # secondary y-axis
        plot.set("y2tics tc lt 2")
        plot.set('y2label "cumulative total number of users" tc lt 2')
        plot.set('format y2 "%.0f"')

        # start plotting the data from largest to smallest so
        # that the shorter bars overlay the taller bars

        # plot all users
        options = {:with => "impulses", :linecolor => COLOURS[:lightblue],
                   :linewidth => 15, :title => "users each day ... who registered"}
        all_users = select_as_columns(aggregate_signups)

        # nothing to do, bail
        abort "warning: no user data to graph, skipping task" unless all_users

        plot_data_from_columns(all_users, options, plot.data)

        # plot confirmed users
        options[:title] = "... and since confirmed their email"
        options[:linecolor] = COLOURS[:mauve]
        plot_data_from_sql(confirmed_users, options, plot.data)

        # plot active users
        options[:with] = "lines"
        options[:title] = "... who made an FOI request"
        options[:linecolor] = COLOURS[:red]
        options.delete(:linewidth)
        plot_data_from_sql(active_users, options, plot.data)

        # plot cumulative user totals
        options[:title] = "cumulative total number of users"
        options[:axes] = "x1y2"
        options[:linecolor] = COLOURS[:lightgreen]
        options[:using] = "1:3"
        plot_data_from_columns(all_users, options, plot.data)
      end
    end
  end

  task :generate_request_creation_graph => :environment do
    # set the local font path for the current task
    ENV["GDFONTPATH"] = "/usr/share/fonts/truetype/ttf-bitstream-vera"

    def assemble_sql(where_clause="")
      "SELECT DATE(created_at), COUNT(*) " \
              "FROM info_requests " \
              "WHERE #{where_clause} " \
              "AND PROMINENCE != 'backpage' " \
              "GROUP BY DATE(created_at)" \
              "ORDER BY DATE(created_at)"
    end

    Gnuplot.open(false) do |gp|
      Gnuplot::Plot.new(gp) do |plot|
        plot.terminal("png font 'Vera.ttf' 9 size 1600,600")
        plot.output(File.expand_path("public/foi-live-creation.png", Rails.root))

        #general settings
        plot.unset(:border)
        plot.unset(:arrow)
        plot.key("left")
        plot.tics("out")

        # x-axis
        plot.xdata("time")
        plot.set('timefmt "%Y-%m-%d"')
        plot.set('format x "%d %b %Y"')
        plot.set("xtics nomirror")
        plot.xlabel("status of requests that were created on each calendar day")

        # primary y-axis
        plot.ylabel("number of requests created on the calendar day")

        # secondary y-axis
        plot.set("y2tics tc lt 2")
        plot.set('y2label "cumulative total number of requests" tc lt 2')
        plot.set('format y2 "%.0f"')

        # get the data, plot the graph

        options = {:with => "impulses", :linecolor => COLOURS[:darkblue],
                   :linewidth => 4, :title => "awaiting_response"}

        # here be database-specific dragons...
        # this uses a window function which is not supported by MySQL, but
        # is reportedly available in MariaDB from 10.2 onward (and Postgres 9.1+)

        sql = "SELECT DATE(created_at), COUNT(*), SUM(count(*)) " \
              "OVER (ORDER BY DATE(created_at)) " \
              "FROM info_requests " \
              "WHERE prominence != 'backpage' " \
              "GROUP BY DATE(created_at)"

        all_requests = select_as_columns(sql)

        # nothing to do, bail
        abort "warning: no request data to graph, skipping task" unless all_requests

        plot_data_from_columns(all_requests, options, plot.data)

        # start plotting the data from largest to smallest so
        # that the shorter bars overlay the taller bars

        sql = assemble_sql("described_state NOT IN ('waiting_response')")
        options[:title] = "waiting_clarification"
        options[:linecolor] = COLOURS[:lightblue]
        plot_data_from_sql(sql, options, plot.data)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification')")
        options[:title] = "not_held"
        options[:linecolor] = COLOURS[:yellow]
        plot_data_from_sql(sql, options, plot.data)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held')")
        options[:title] = "rejected"
        options[:linecolor] = COLOURS[:red]
        plot_data_from_sql(sql, options, plot.data)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected')")
        options[:title] = "successful"
        options[:linecolor] = COLOURS[:lightgreen]
        plot_data_from_sql(sql, options, plot.data)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected', 'successful')")
        options[:title] = "partially_successful"
        options[:linecolor] = COLOURS[:darkgreen]
        plot_data_from_sql(sql, options, plot.data)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected', 'successful', 'partially_successful')")
        options[:title] = "requires_admin"
        options[:linecolor] = COLOURS[:cyan]
        plot_data_from_sql(sql, options, plot.data)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected', 'successful', 'partially_successful', 'requires_admin')")
        options[:title] = "gone_postal"
        options[:linecolor] = COLOURS[:darkyellow]
        plot_data_from_sql(sql, options, plot.data)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected', 'successful', 'partially_successful', 'requires_admin', 'gone_postal')")
        options[:title] = "internal_review"
        options[:linecolor] = COLOURS[:mauve]
        plot_data_from_sql(sql, options, plot.data)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected', 'successful', 'partially_successful', 'requires_admin', 'gone_postal', 'internal_review')")
        options[:title] = "error_message"
        options[:linecolor] = COLOURS[:redbrown]
        plot_data_from_sql(sql, options, plot.data)

        sql = assemble_sql("described_state NOT IN ('waiting_response', 'waiting_clarification', 'not_held', 'rejected', 'successful', 'partially_successful', 'requires_admin', 'gone_postal', 'internal_review', 'error_message')")
        options[:title] = "user_withdrawn"
        options[:linecolor] = COLOURS[:pink]
        plot_data_from_sql(sql, options, plot.data)

        # plot the cumulative counts
        options[:with] = "lines"
        options[:linecolor] = COLOURS[:lightgreen]
        options[:title] = "cumulative total number of requests"
        options[:using] = "1:3"
        options[:axes] = "x1y2"
        options.delete(:linewidth)
        plot_data_from_columns(all_requests, options, plot.data)
      end
    end
  end
end

