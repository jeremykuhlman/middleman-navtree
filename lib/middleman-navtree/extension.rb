require 'middleman-navtree/helpers'
# require 'pry'

module Middleman
  module NavTree

    # Extension namespace
    # @todo: Test the extension against a vanilla Middleman install.
    # @todo: Test the extension against a middleman-blog install.
    class NavTreeExtension < ::Middleman::Extension
      # All the options for this extension
      option :source_dir, 'source', 'The directory our tree will begin at.' # This setting does nothing but remains listed for backwards compatibility.
      option :data_file, 'tree.yml', 'The file we will write our directory tree to.'
      option :automatic_tree_updates, true, 'The tree.yml file will be updated automatically when source files are changed.'
      option :ignore_files, ['sitemap.xml', 'robots.txt'], 'A list of filenames we want to ignore when building our tree.'
      option :ignore_dir, ['assets'], 'A list of directory names we want to ignore when building our tree.'
      option :home_title, 'Home', 'The default link title of the home page (located at "/"), if otherwise not detected.'
      option :ext_whitelist, [], 'A whitelist of filename extensions (post-render) that we are allowing in our navtree. Example: [".html"]'
      option :directory_index, false, "Enables directory indexing, where directories with index files will be rendered as links"
      option :navigation_tree_wrapper, File.expand_path('../views/_navigation_tree_wrapper.html.erb', __FILE__), 'Path (relative to project root) to an ERb template that will be used to generate the tree wrapper.'
      option :navigation_tree_items_container, File.expand_path('../views/_navigation_tree_items_container.html.erb', __FILE__), 'Path (relative to project root) to an ERb template that will be used to generate the tree items container.'
      option :navigation_tree_item_child, File.expand_path('../views/_navigation_tree_item_child.html.erb', __FILE__), 'Path (relative to project root) to an ERb template that will be used to generate the tree item child.'
      option :navigation_tree_item_directory_index_linked, File.expand_path('../views/_navigation_tree_item_directory_index_linked.html.erb', __FILE__), 'Path (relative to project root) to an ERb template that will be used to generate the linked tree item child if directory indexes is activiated.'
      option :navigation_tree_item_directory_index_non_linked, File.expand_path('../views/_navigation_tree_item_directory_index_non_linked.html.erb', __FILE__), 'Path (relative to project root) to an ERb template that will be used to generate the non linked tree item child if directory indexes is activiated.'

      # Helpers for use within templates and layouts.
      self.defined_helpers = [ ::Middleman::NavTree::Helpers ]

      def initialize(app, options_hash={}, &block)
        # Call super to build options from the options_hash
        super

        # Require libraries only when activated
        require 'yaml'
        require 'titleize'

      end

      def after_configuration

        # Add the user's config directories to the "ignore_dir" option because these are all things we won't need printed in a NavTree.
        options.ignore_dir << app.config[:js_dir]
        options.ignore_dir << app.config[:css_dir]
        options.ignore_dir << app.config[:fonts_dir]
        options.ignore_dir << app.config[:images_dir]
        options.ignore_dir << app.config[:helpers_dir]
        options.ignore_dir << app.config[:layouts_dir]
        options.ignore_dir << app.config[:partials_dir]

        # Build a hash out of our directory information
        tree_hash = scan_directory(app.config[:source], options)

        # Write our directory tree to file as YAML.
        # @todo: This step doesn't rebuild during live-reload, which causes errors if you move files around during development. It may not be that hard to set up. Low priority though.
        if options.automatic_tree_updates
          FileUtils.mkdir_p(app.config[:data_dir])

          data_path = app.config[:data_dir] + '/' + options.data_file
          IO.write(data_path, YAML::dump(tree_hash))
        end
      end

      # Method for storing the directory structure in an ordered hash. See more on ordered hashes at https://www.igvita.com/2009/02/04/ruby-19-internals-ordered-hash/
      def scan_directory(path, options, name=nil)

        data = {}
        Dir.foreach(path) do |filename|

          # Check to see if we should skip this file. We skip invisible files (starts with ".") and ignored files.
          next if (filename[0] == '.')
          next if (filename == '..' || filename == '.')
          next if options.ignore_files.include? filename

          full_path = File.join(path, filename)
          if File.directory?(full_path)

            # This item is a directory.  Check to see if we should ignore this directory.
            next if options.ignore_dir.include? filename

            # Loop through the method again.
            position = get_directory_display_order(full_path)
            data.store((position ? "#{'%04d' % position}-" : "") + filename.gsub(' ', '%20'), scan_directory(full_path, options, filename))

          else
            # This item is a file.
            if !options.ext_whitelist.empty?

              # Skip any whitelisted extensions.
              next unless options.ext_whitelist.include? File.extname(filename)
            end

            original_path = path.sub(/^#{app.config[:source]}/, '') + '/' + filename

            # Get this resource so we can figure out the display order
            this_resource = resource_from_value(original_path)
            position =  get_file_display_order(this_resource)

            data.store((position ? "#{'%04d' % position}-" : "") + filename.gsub(' ', '%20'), original_path.gsub(' ', '%20'))
          end
        end

        # Return this level's data as a hash sorted by keys.
        return Hash[data.sort]
      end

      # Returns a resource from a provided value
      def resource_from_value(value)

        extensionlessPath = app.sitemap.extensionless_path(value)

        unless extensionlessPath.end_with? ".html"
         extensionlessPath << ".html"
        end

        app.sitemap.find_resource_by_path(extensionlessPath)
      end

      # Gets the display order for a file
      def get_file_display_order(file)
        if !file.nil? && file.data.display_order
          return file.data.display_order
        end
      end

      # Gets the display order for a directory
      def get_directory_display_order(directory)

        # Check for a .display_info file
        if File.file?("#{directory}/.display_info")
          File.read("#{directory}/.display_info").each_line do |line|

            kv = line.split(":")

            # Get the "display_order" value
            if kv[0].strip == "display_order"
              return kv[1].strip
            end
          end
        end
      end
    end
  end
end