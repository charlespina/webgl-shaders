module.exports = function(grunt) {
  grunt.initConfig({
    watch: {
      html: {
        files: "**/*.html",
        options: {
          livereload: true
        }
      }
    },
  });

  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.registerTask('default', ['watch:html']);
};
