<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Node.js Benchmark Results</title>
    <link rel="stylesheet" type="text/css" href="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/css/bootstrap.min.css" integrity="sha384-Vkoo8x4CGsO3+Hhxv8T/Q5PaXtkKtu6ug5TOeNV6gBiFeWPGFN9MuhOf23Q9Ifjh" crossorigin="anonymous">
    <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/v/bs4/jszip-2.5.0/dt-1.10.20/b-1.6.1/b-html5-1.6.1/r-2.2.3/sl-1.3.1/datatables.min.css"/>
    <link rel="stylesheet" type="text/css" href="https://bootswatch.com/4/spacelab/bootstrap.min.css"/>
    <script src="https://code.jquery.com/jquery-3.4.1.slim.min.js" integrity="sha384-J6qa4849blE2+poT4WnyKhv5vZF5SrPo0iEjwBvKU7imGFAV0wwj1yYfoRSJoZ+n" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/popper.js@1.16.0/dist/umd/popper.min.js" integrity="sha384-Q6E9RHvbIyZFJoft+2mJbHaEWldlvI9IOYy5n3zV9zzTtmI3UksdQRVvoxMfooAo" crossorigin="anonymous"></script>
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/4.4.1/js/bootstrap.min.js" integrity="sha384-wfSDF2E50Y2D1uUdj0O3uMBJnjuUD4Ih7YwaYd1iqfktj0Uod8GCExl3Og8ifwB6" crossorigin="anonymous"></script>
    <script src="https://cdn.datatables.net/v/bs4/jszip-2.5.0/dt-1.10.20/b-1.6.1/b-html5-1.6.1/r-2.2.3/sl-1.3.1/datatables.min.js"></script>
    <script src="js/ttest.js"></script>
    <script src="js/main.js"></script>
    <script>
      var index = #DATA_JSON#;

      $(document).ready(function() {
        var dtCommitList;
        var dtResultsCompare;
        var dtResultsSingle;
        var dtRuntimes;

        var RE_PATH_HASH = /-([A-Za-z0-9]+)$/;
        (function() {
          var RE_COMMIT = /^(\d{2})_(\d{2})(\d{2})(\d{2})(\d{3})[^-]*-([A-Za-z0-9]+)$/;
          var html = '';
          var yearsObj = index['nodejs~node']['master'];
          var years = Object.keys(yearsObj);
          for (var y = 0; y < years.length; ++y) {
            var year = years[y];
            var monthsObj = yearsObj[year];
            var months = Object.keys(monthsObj);
            for (var m = 0; m < months.length; ++m) {
              var month = months[m];
              var commits = Object.keys(monthsObj[month]);
              for (var c = 0; c < commits.length; ++c) {
                var commit = commits[c];
                var parts = RE_COMMIT.exec(commit);
                var date = parts[1];
                var hour = parts[2];
                var mins = parts[3];
                var secs = parts[4];
                var msecs = parts[5];
                var hash = parts[6];
                var dt = year + '-' + month + '-' + date + ' '
                         + hour + ':' + mins + ':' + secs + '.' + msecs;
                var path = year + '/' + month + '/' + commit;
                html += '<tr data-path="' + path + '"><td>' + dt + '</td><td><a href="https://github.com/nodejs/node/tree/' + hash + '" target="_blank">' + hash + '</a></td><td></td></tr>';
              }
            }
          }
          $('#commit-list tbody').html(html);

          dtCommitList = $('#commit-list').DataTable({
            order: [[ 0, 'desc' ]],
            columnDefs: [{
              targets: -1,
              data: null,
              orderable: false,
              // The "navbar" container here is a hack to workaround a bug with
              // Bootstrap's dropdown being displayed in the wrong position on
              // the page the first time it's shown
              defaultContent: '<div class="navbar">\
                                <div class="btn-group">\
                                  <button type="button" class="btn btn-sm btn-info dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">\
                                    View ...\
                                  </button>\
                                  <div class="dropdown-menu">\
                                    <button class="dropdown-item" type="button">Runtimes</button>\
                                    <button class="dropdown-item" type="button">All Categories</button>\
                                    <div class="dropdown-divider"></div>\
                                    <h6 class="dropdown-header">Individual Categories</h6>\
                                  </div>\
                                </div>\
                              </div>',
            }],
            select: {
              info: false,
              items: 'row',
              style: 'os'
            }
          });
          dtCommitList.on('select', updateSelection)
                      .on('deselect', updateSelection);
          $('#commit-list tbody').on('click', 'button', function(e) {
            var $this = $(this);
            var $tr = $this.parents('tr');
            var path = $tr.data('path');
            if ($this.hasClass('dropdown-item')) {
              var selectedItem = $(e.target).text();

              $('#loading-modal').modal('show');
              switch (selectedItem) {
                case 'Runtimes':
                  fetchSingleRuntimes(path, function(err, times, total) {
                    $('#loading-modal').modal('hide');
                    if (err)
                      return alert(err.message);

                    $('#results-section').hide();

                    $('#runtime-total').text(total);
                    $('#runtimes').find('thead th:nth-child(2)').text('Time');
                    $('#runtimes-title').html('Run-times for ' + $tr.find('td:nth-child(2)').html());
                    dtRuntimes.clear().rows.add(times).draw();

                    $('#runtimes-section').show();
                  });
                  break;
                case 'All Categories':
                  fetchCategories(path, function(err, categories) {
                    if (err) {
                      $('#loading-modal').modal('hide');
                      return alert(err.message);
                    }

                    var tasks = [];
                    for (var i = 0; i < categories.length; ++i) {
                      tasks.push([
                        fetchSingleResults,
                        [path + '/' + categories[i] + '.json'],
                      ]);
                    }

                    parallel(tasks, function(err, results) {
                      $('#loading-modal').modal('hide');
                      if (err)
                        return alert(err.message);

                      $('#results-title').html('Results for ' + $tr.find('td:nth-child(2)').html());
                      dtResultsSingle.clear();
                      var rows = dtResultsSingle.rows;
                      for (var i = 0; i < results.length; ++i)
                        rows.add(results[i][0]);
                      dtResultsSingle.draw();

                      $('#runtimes-section').hide();
                      $(dtResultsCompare.table().container()).hide();
                      $(dtResultsSingle.table().container()).show();
                      $('#results-section').show();
                    });
                  });
                  break;
                default:
                  fetchSingleResults(path + '/' + selectedItem + '.json', function(err, data) {
                    $('#loading-modal').modal('hide');
                    if (err)
                      return alert(err.message);

                    $('#runtimes-section').hide();
                    $(dtResultsCompare.table().container()).hide();

                    $('#results-title').html('Results for <code>' + selectedItem + '</code> for ' + $tr.find('td:nth-child(2)').html());
                    dtResultsSingle.clear().rows.add(data).draw();

                    $(dtResultsSingle.table().container()).show();
                    $('#results-section').show();
                  });
              }
              return;
            }

            if ($this.data('loaded'))
              return;

            $this.prop('disabled', true);
            $this.text('Loading ...');
            fetchCategories(path, function(err, categories) {
              $this.prop('disabled', false);
              if (err) {
                $this.text('Fetch Metadata');
                alert(err.message);
                return;
              }

              $this.data('loaded', true);
              var $menu = $this.siblings('div.dropdown-menu');
              for (var i = 0; i < categories.length; ++i) {
                $menu.append('<button class="dropdown-item" type="button">'
                               + categories[i] + '</button>');
              }
              $this.dropdown('show');
              $this.text(' View ... ');
            });

            return false;
          });

          dtCommitList.on('user-select', function(e, dt, type, cell, originalEvent) {
            var child = originalEvent.currentTarget.firstElementChild;
            if (child && child.contains(originalEvent.target))
              return false;
          });
          function updateSelection(e, dt, type, ix) {
            var selected = dt.rows({ selected: true });
            switch (selected.count()) {
              case 0:
              case 1:
                btnCompareSel.setAttribute('disabled', '');
                break;
              case 2:
                btnCompareSel.removeAttribute('disabled');
                break;
              default:
                dt.rows(ix).deselect();
            }
          }
        })();

        function getCommonCategories(cb) {
          var selNodes = dtCommitList.rows({ selected: true }).nodes();
          var firstPath = $(selNodes[0]).data('path');
          var secondPath = $(selNodes[1]).data('path');

          parallel([
            [fetchCategories, [firstPath]],
            [fetchCategories, [secondPath]],
          ], function(err, results) {
            if (err)
              return cb(err);

            var firstCategories = results[0][0];
            var secondCategories = results[1][0];
            var categories = [];

            for (var i = 0; i < firstCategories.length; ++i) {
              var category = firstCategories[i];
              if (secondCategories.indexOf(category) !== -1)
                categories.push(category);
            }

            if (categories.length === 0)
              return cb(new Error('Selected commits have no categories in common'));

            cb(null, categories);
          });
        }
        $(btnCompareSel).click(function() {
          var $this = $(this);

          $this.prop('disabled', true);
          $this.text('Loading ...');
          getCommonCategories(function(err, categories) {
            $this.prop('disabled', false);
            $this.text('Compare Selected ...');

            if (err)
              return alert(err.message);

            var $menu = $this.siblings('.dropdown-menu');
            $menu.children('button.dropdown-item').slice(2).remove();

            for (var i = 0; i < categories.length; ++i) {
              $menu.append('<button class="dropdown-item" type="button">'
                           + categories[i] + '</button>');
            }

            requestAnimationFrame(function() {
              $this.dropdown('show');
            });
          });

          return false;
        });
        $(btnCompareSel).siblings('.dropdown-menu').on('click', 'button.dropdown-item', function(e) {
          var $this = $(this);
          var selectedItem = $this.text();
          var selected = dtCommitList.rows({ selected: true });
          var selData = selected.data();
          var oldIdx;
          var newIdx;
          if (selData[0] < selData[1]) {
            oldIdx = 0;
            newIdx = 1;
          } else {
            oldIdx = 1;
            newIdx = 0;
          }
          var selNodes = selected.nodes();
          var $oldRow = $(selNodes[oldIdx]);
          var oldPath = $oldRow.data('path');
          var $newRow = $(selNodes[newIdx]);
          var newPath = $newRow.data('path');

          $('#loading-modal').modal('show');
          switch (selectedItem) {
            case 'Runtimes':
              compareRuntimes(oldPath + '/_metadata.json',
                              newPath + '/_metadata.json',
                              function(err, results) {
                $('#loading-modal').modal('hide');
                if (err)
                  return alert(err.message);

                var diffs = results[0];
                var totalDiff = results[1];

                $('#results-section').hide();

                $('#runtime-total').text(totalDiff).attr('class', (totalDiff[0] === '+' ? 'diff-neg' : 'diff-pos'));
                $('#runtimes').find('thead th:nth-child(2)').text('Difference');
                var $oldHash = $oldRow.find('td:nth-child(2)');
                var $newHash = $newRow.find('td:nth-child(2)');
                var compareLink = 'https://github.com/nodejs/node/compare/'
                                  + $oldHash.text() + '...' + $newHash.text();
                $('#runtimes-title').html('Run-time differences from ' + $oldHash.html() + ' <a href="' + compareLink + '" target="_blank">to</a> ' + $newHash.html());
                dtRuntimes.clear().rows.add(diffs).draw();

                $('#runtimes-section').show();
              });
              break;
            case 'All Categories':
              getCommonCategories(function(err, categories) {
                if (err) {
                  $('#loading-modal').modal('hide');
                  return alert(err.message);
                }

                var tasks = [];
                for (var i = 0; i < categories.length; ++i) {
                  tasks.push([
                    compareResults,
                    [oldPath + '/' + categories[i] + '.json',
                     newPath + '/' + categories[i] + '.json'],
                  ]);
                }

                parallel(tasks, function(err, results) {
                  $('#loading-modal').modal('hide');
                  if (err)
                    return alert(err.message);

                  var $oldHash = $oldRow.find('td:nth-child(2)');
                  var $newHash = $newRow.find('td:nth-child(2)');
                  var compareLink = 'https://github.com/nodejs/node/compare/'
                                    + $oldHash.text() + '...' + $newHash.text();
                  $('#results-title').html('Results from ' + $oldHash.html() + ' <a href="' + compareLink + '" target="_blank">to</a> ' + $newHash.html());
                  dtResultsCompare.clear();
                  var rows = dtResultsCompare.rows;
                  for (var i = 0; i < results.length; ++i)
                    rows.add(results[i][0]);
                  dtResultsCompare.draw();

                  $('#runtimes-section').hide();
                  $(dtResultsSingle.table().container()).hide();
                  $(dtResultsCompare.table().container()).show();
                  $('#results-section').show();
                });
              });
              break;
            default:
              compareResults(oldPath + '/' + selectedItem + '.json',
                             newPath + '/' + selectedItem + '.json',
                             function(err, results) {
                $('#loading-modal').modal('hide');
                if (err)
                  return alert(err.message);

                var $oldHash = $oldRow.find('td:nth-child(2)');
                var $newHash = $newRow.find('td:nth-child(2)');
                var compareLink = 'https://github.com/nodejs/node/compare/'
                                  + $oldHash.text() + '...' + $newHash.text();
                $('#results-title').html('Results for <code>' + selectedItem + '</code> from ' + $oldHash.html() + ' <a href="' + compareLink + '" target="_blank">to</a> ' + $newHash.html());
                dtResultsCompare.clear().rows.add(results).draw();

                $('#runtimes-section').hide();
                $(dtResultsSingle.table().container()).hide();
                $(dtResultsCompare.table().container()).show();
                $('#results-section').show();
              });
          }
        });

        dtResultsCompare = $('#results-compare').DataTable({
          order: [[ 0, 'asc' ], [ 1, 'asc' ], [ 2, 'asc' ]],
          pageLength: 50,
          columnDefs: [{
            targets: 3,
            render: function(data, type, row, meta) {
              switch (type) {
                case 'display':
                case 'filter':
                  data = '';
                  break;
              }
              return data;
            },
            createdCell: function(td, cellData, rowData, row, col) {
              switch (cellData) {
                case -1:
                  $(td).addClass('confNA');
                  break;
                case 1:
                case 2:
                case 3:
                  $(td).addClass('conf' + cellData);
                  break;
              }
            },
          }, {
            targets: 4,
            render: function(data, type, row, meta) {
              switch (type) {
                case 'display':
                case 'filter':
                  data = data.toFixed(2) + ' %';
                  if (data[0] !== '-')
                    data = '+' + data;
                  break;
              }
              return data;
            },
            createdCell: function(td, cellData, rowData, row, col) {
              $(td).addClass(cellData < 0 ? 'diff-neg' : 'diff-pos');
            },
          }],
        });

        dtResultsSingle = $('#results-single').DataTable({
          order: [[ 0, 'asc' ], [ 1, 'asc' ], [ 2, 'asc' ]],
          pageLength: 50,
          columnDefs: [{
            targets: -1,
            type: 'num',
          }],
        });

        dtRuntimes = $('#runtimes').DataTable({
          order: [[ 0, 'asc' ]],
          pageLength: 50,
          columnDefs: [{
            targets: -1,
            createdCell: function(td, cellData, rowData, row, col) {
              if (typeof cellData !== 'string' || !cellData)
                return;
              switch (cellData[0]) {
                case '+':
                  $(td).addClass('diff-neg');
                  break;
                case '-':
                  $(td).addClass('diff-pos');
                  break;
              }
            },
          }],
        });

        $('#loading-modal').modal();
      });
    </script>
    <style>
      body {
        padding: 10px;
      }

      #results-section,
      #runtimes-section {
        display: none;
      }

      table#commit-list tbody tr td,
      table#runtimes tbody tr td:nth-child(2),
      table#results-compare tbody tr td:nth-child(5) {
        font-family: monospace;
        font-size: 1.3rem;
      }
      table#commit-list tbody tr td:nth-child(2),
      table#runtimes tbody tr td:nth-child(2),
      table#results-compare tbody tr td:nth-child(4),
      table#results-compare tbody tr td:nth-child(5) {
        font-weight: bold;
      }
      table#results-compare tbody tr td:nth-child(5) {
        text-align: right
      }
      table#results-compare tbody tr td:nth-child(4) {
        text-align: right;
        width: 100px;
        vertical-align: middle;
        line-height: 1rem;
        color: black;
        font-size: 2.3rem;
      }
      td.confNA {
        background-color: #666;
      }
      td.conf1:before {
        content: '•'
      }
      td.conf2:before {
        content: '••'
      }
      td.conf3:before {
        content: '•••'
      }
      .diff-pos {
        background-color: darkgreen;
        color: white;
      }
      .diff-neg {
        background-color: darkred;
        color: white;
      }
      table.dataTable.order-column tbody tr > .sorting_1,
      table.dataTable.order-column tbody tr > .sorting_2,
      table.dataTable.order-column tbody tr > .sorting_3,
      table.dataTable.order-column tbody tr > .sorting_4 {
        background-color: #ccc;/*#f9f9f9;*/
      }
      hr {
        border-top: 1px solid black;
      }
      #runtime-total {
        display: inline-block;
        font-family: monospace;
        font-weight: bold;
        font-size: 1.2rem;
        padding: 5px;
        vertical-align: middle;
      }
      #runtime-total-info {
        display: inline-block;
        font-weight: bold;
        border: 1px solid gray;
        padding: 10px;
        margin-bottom: 5px;
      }
      table tbody tr td {
        vertical-align: middle !important;
      }
      #loading-modal .modal-content {
        padding: 10px;
        text-align: center;
        font-size: 2rem;
      }
    </style>
  </head>
  <body>
    <h1>Available Commits</h1>
    <div style="margin-bottom: 10px">
      <div class="btn-group">
        <button type="button" id="btnCompareSel" class="btn btn-primary dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false" disabled>
          Compare Selected ...
        </button>
        <div class="dropdown-menu">
          <button class="dropdown-item" type="button">Runtimes</button>
          <button class="dropdown-item" type="button">All Categories</button>
          <div class="dropdown-divider"></div>
          <h6 class="dropdown-header">Individual Categories</h6>
        </div>
      </div>
    </div>
    <table id="commit-list" class="table table-bordered table-hover table-sm compact">
      <thead>
        <tr>
          <th>Build Date/Time (EST)</th>
          <th>Commit</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
      </tbody>
    </table>
    <div id="results-section">
      <hr />
      <h1 id="results-title">Results</h1>
      <table id="results-compare" class="table table-bordered table-hover table-sm compact">
        <thead>
          <tr>
            <th>Category</th>
            <th>Benchmark</th>
            <th>Configuration</th>
            <th>Confidence</th>
            <th>Difference</th>
          </tr>
        </thead>
        <tbody>
        </tbody>
      </table>
      <table id="results-single" class="table table-bordered table-hover table-sm compact">
        <thead>
          <tr>
            <th>Category</th>
            <th>Benchmark</th>
            <th>Configuration</th>
            <th>Average</th>
          </tr>
        </thead>
        <tbody>
        </tbody>
      </table>
    </div>
    <div id="runtimes-section">
      <hr />
      <h1 id="runtimes-title">Run-times</h1>
      <div id="runtime-total-info">Total: <div id="runtime-total"></div></div>
      <table id="runtimes" class="table table-bordered table-hover table-sm compact">
        <thead>
          <tr>
            <th>Category</th>
            <th>Time/Difference</th>
          </tr>
        </thead>
        <tbody>
        </tbody>
      </table>
    </div>
    <div id="loading-modal" class="modal" data-backdrop="static" data-keyboard="false" data-show="false">
      <div class="modal-dialog modal-sm modal-dialog-centered" role="document">
        <div class="modal-content">
          Loading ...
        </div>
      </div>
    </div>
  </body>
</html>
