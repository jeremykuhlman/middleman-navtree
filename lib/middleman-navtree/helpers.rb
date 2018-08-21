module Middleman
  module NavTree

    # NavTree-related helpers that are available to the Middleman application in +config.rb+ and in templates.
    module Helpers

      # A helper to create the entire tree structure from source tree data
      def build_full_navigation_tree(value)
        render_partial(extensions[:navtree].options[:navigation_tree_wrapper], { :navigation_tree => build_partial_navigation_tree(value) })
      end

      #  A recursive helper for converting source tree data
      def build_partial_navigation_tree(value, depth = Float::INFINITY, key = nil, level = 0)
        navigation_tree = ""

        if value.is_a?(String)

          # This is a file.
          # Get the Sitemap resource for this file.
          # note: sitemap.extensionless_path converts the path to its 'post-build' extension.
          this_resource = resource_from_value(value)

          return "" if this_resource.nil?

          unless extensions[:navtree].options[:directory_index] && this_resource.directory_index?
            navigation_tree << child_li(this_resource) if this_resource
          end
        else

          # This is the first level source directory. We treat it special because it has no key and needs no list item.
          if key.nil?
            value.each do |newkey, child|
              navigation_tree << build_partial_navigation_tree(child, depth, newkey, level + 1)
            end

          # Continue rendering deeper levels of the tree, unless restricted by depth.
          elsif depth >= (level + 1)

            # Loop through all the directory's contents.
            directory_content = ""
            value.each do |newkey, child|
              directory_content << build_partial_navigation_tree(child, depth, newkey, level + 1)
            end

            directory_content_html = render_partial(extensions[:navtree].options[:navigation_tree_items_container], { :directory_content => directory_content })

            # This is a directory.
            # The directory has a key and should be listed in the page hieararcy with HTML.
            navigation_tree << parent_li(key, value, directory_content_html)
          end
        end

        return navigation_tree
      end

      # Helper for use in pagination methods.
      def get_current_position_in_page_list(pagelist)

        pagelist.each_with_index do |page_path, index|
          if page_path == "/" + current_page.path
            return index
          end
        end

        # If we reach this line, the current page path wasn't in our page list and we'll return false so the link generation is skipped.
        return FALSE
      end

      # Utility helper for getting the page title for display in the navtree.
      def discover_file_title(page = current_page)

        if page.data.title
          return page.data.title # Frontmatter title
        else
          filename = page.url.split(/\//).last.gsub('%20', ' ').titleize

          return filename.chomp(File.extname(filename))
        end
      end

      # Utility helper for getting the directory title for display in the navtree.
      def discover_directory_title(name, directory_path)

        # Check for a .display_info file in the source directory
        display_info_file_path = File.join("source", directory_path, ".display_info")

        if File.file?(display_info_file_path)

            display_info_hash = YAML.load_file(display_info_file_path)

            return display_info_hash.has_key?("title") ? display_info_hash["title"] :  "No Title Key Set"
        else

          # No file found, so just parse the directory name
          return name.gsub("%20", " ").titleize
        end
      end

      private

      # generates an HTML li child from a given resource
      def child_li(resource)
        title = discover_file_title(resource)

        render_partial(extensions[:navtree].options[:navigation_tree_item_child], {:url => resource.url, :resource_status => resource_status(resource), :title => title })
      end

      # returns a resource from a provided value
      def resource_from_value(value)

        extensionlessPath = sitemap.extensionless_path(value)

        unless extensionlessPath.end_with? ".html"
         extensionlessPath << ".html"
        end
        sitemap.find_resource_by_path(extensionlessPath)
      end

      # generate a linked li.parent otherwise returns a normal (non-linked) HTML li.parent
      def parent_li(key, value, directory_content_html)

        # Get the directory path from the first key/value file path that isn't another hash
        directory_path = value[value.keys.select{ |x| value[x].is_a?(String) }.first]

        # Determine the directory title either from the key or the first key/value pair that isn't another directory
        name = discover_directory_title(key, File.dirname(directory_path))

        if extensions[:navtree].options[:directory_index] && index_file = value.keys.detect{|k| k.start_with?("index")}

          # removes index.html from some/directory/index.html
          destination = value[index_file].split("/")[0..-2].join("/") + "/"

          resource_path = destination.sub(/\A\//, "").sub(".md.erb", "").gsub("%20", " ")
          resource_path += "index" if resource_path.ends_with?("/")
          resource = sitemap.find_resource_by_page_id(resource_path)

          render_partial(extensions[:navtree].options[:navigation_tree_item_directory_index_linked], {:url => destination, :resource_status => resource_status(resource), :name => name, :directory_content_html => directory_content_html })
        else
          render_partial(extensions[:navtree].options[:navigation_tree_item_directory_index_non_linked], { :name => name, :directory_content_html => directory_content_html })
        end
      end

      # checks if this resource is the current page returns active if it is, an empty string otherwise
      def resource_status(resource)
        resource == current_page ? "active" : ""
      end

      # renders a partial template
      def render_partial(partial, content)
        template = ERB.new(File.read partial)
        content_binding = binding_from_hash(content)
        template.result(content_binding).html_safe
      end

      # used to pass parameters to our ERB partial templates
      def clean_binding
        binding
      end

      # used to pass parameters to our ERB partial templates
      def binding_from_hash(**vars)
        b = clean_binding
        vars.each do |k, v|
          b.local_variable_set k.to_sym, v
        end

        return b
      end

    end
  end
end
