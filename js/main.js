'use strict';

var BASE_PATH = 'results/nodejs~node/master/';
var RE_CATEGORY = /\/([^/]+)\.json$/;

function parallel(tasks, cb) {
  var results = new Array(tasks.length);
  var finished = new Array(tasks.length);
  var tasksLeft = tasks.length;

  var finalCallback = (function() {
    var called = false;
    return function finalCallback() {
      if (called)
        return;
      called = true;
      cb.apply(null, arguments);
    };
  })();

  for (var i = 0; i < tasks.length; ++i) {
    var task = tasks[i];
    var args = task[1].slice();
    args.push(makeCallback(i));
    task[0].apply(null, args);
  }

  function makeCallback(idx) {
    return function taskCallback(err) {
      if (finished[idx])
        return;
      finished[idx] = true;

      if (err)
        return finalCallback(err);

      results[idx] = Array.prototype.slice.call(arguments, 1);
      if (--tasksLeft === 0)
        finalCallback(err, results);
    };
  }
}

var formatHMSTime = (function() {
  return function formatHMSTime(secs) {
    var hours = pad('' + Math.floor(secs / 3600));
    var mins = pad('' + Math.floor((secs % 3600) / 60));
    var secs = pad('' + ((secs % 3600) % 60));
    return hours + ':' + mins + ':' + secs;
  };

  function pad(str) {
    switch (str.length) {
      case 0: return '00';
      case 1: return '0' + str;
      default: return str;
    }
  }
})();

function toSecs(str) {
  var firstSep = str.indexOf(':');
  var lastSep = str.lastIndexOf(':');
  return ((+str.slice(0, firstSep)) * 3600)
         + ((+str.slice(firstSep + 1, lastSep)) * 60)
         + (+str.slice(lastSep + 1));
}

function doFetch(path, cb) {
  var req = new XMLHttpRequest();
  req.onreadystatechange = function() {
    if (req.readyState === XMLHttpRequest.DONE) {
      if (req.status === 200)
        cb(null, req.responseText);
      else
        cb(new Error('Unexpected ' + req.status + ' response from server'));
    }
  };
  req.open('GET', path, true);
  req.send();
}

var fetchJSON = (function() {
  var cache = Object.create(null);
  var reqs = Object.create(null);

  return function fetchJSON(path, cb) {
    path = BASE_PATH + path;

    var existing = cache[path];
    if (existing !== undefined)
      return cb(null, existing);
    var cbs = reqs[path];
    if (cbs) {
      cbs.push(cb);
      return;
    }
    reqs[path] = cbs = [cb];

    doFetch(path, function(err, res) {
      if (err)
        return doCallbacks(cbs, path, err);
      try {
        res = JSON.parse(res);
      } catch (ex) {
        err = new Error('Unable to parse JSON: ' + ex.message);
        return doCallbacks(cbs, path, err);
      }
      cache[path] = res;
      doCallbacks(cbs, path, null, res);
    });
  };

  function doCallbacks(cbs, path, err, res) {
    delete reqs[path];
    if (err) {
      for (var i = 0; i < cbs.length; ++i)
        cbs[i](err);
    } else {
      for (var i = 0; i < cbs.length; ++i)
        cbs[i](null, res);
    }
  }
})();

function fetchCategories(path, cb) {
  fetchJSON(path + '/_metadata.json', function(err, res) {
    if (err)
      return cb(err);

    var results = [];
    var categories = Object.keys(res.times);
    for (var i = 0; i < categories.length; ++i) {
      var category = categories[i];
      if (category[0] === '_')
        continue;

      results.push(category);
    }

    cb(null, results);
  });
}

function fetchSingleResults(path, cb) {
  var category = RE_CATEGORY.exec(path);
  if (!category)
    return cb(new Error('Invalid data URL'));

  category = category[1];

  fetchJSON(path, function(err, data) {
    if (err)
      return cb(err);

    var results = [];
    var benchmarkNames = Object.keys(data);
    for (var i = 0; i < benchmarkNames.length; ++i) {
      var benchmarkName = benchmarkNames[i];
      var fileGroup = data[benchmarkName];

      var configs = Object.keys(fileGroup);
      for (var j = 0; j < configs.length; ++j) {
        var config = configs[j];
        var calcs = fileGroup[config];

        results.push([
          category,
          benchmarkName,
          config,
          calcs.mean
        ]);
      }
    }

    cb(null, results);
  });
}

function fetchSingleRuntimes(path, cb) {
  fetchJSON(path + '/_metadata.json', function(err, res) {
    if (err)
      return cb(err);

    var results = [];
    var total = 0;
    var categories = Object.keys(res.times);
    for (var i = 0; i < categories.length; ++i) {
      var category = categories[i];
      if (category[0] === '_')
        continue;

      var time = res.times[category];
      total += toSecs(time);
      results.push([category, time]);
    }

    cb(null, results, formatHMSTime(total));
  });
}

var compareResults;
var compareRuntimes;
(function() {
  function makeCompareFn(comparer) {
    return function fetchData(oldPath, newPath, cb) {
      var oldCategory = RE_CATEGORY.exec(oldPath);
      var newCategory = RE_CATEGORY.exec(newPath);
      if (!oldCategory || !newCategory)
        return cb(new Error('Invalid data URL'));

      oldCategory = oldCategory[1];
      newCategory = newCategory[1];
      if (oldCategory !== newCategory)
        return cb(new Error('Categories do not match'));

      parallel([
        [fetchJSON, [oldPath]],
        [fetchJSON, [newPath]],
      ], function(err, results) {
        if (err)
          return cb(err);

        var oldData = results[0][0];
        var newData = results[1][0];
        cb(null, comparer(oldData, newData, oldCategory));
      });
    };
  }

  compareResults = makeCompareFn(function(oldData, newData, category) {
    var results = [];
    var benchmarkNames = Object.keys(oldData);
    for (var i = 0; i < benchmarkNames.length; ++i) {
      var benchmarkName = benchmarkNames[i];
      var fileGroup = oldData[benchmarkName];

      var configs = Object.keys(fileGroup);
      for (var j = 0; j < configs.length; ++j) {
        var config = configs[j];
        var oldCalcs = fileGroup[config];
        var newCalcs =
          (newData[benchmarkName] && newData[benchmarkName][config]);
        if (!newCalcs)
          continue;

        var oldMean = oldCalcs.mean;
        var newMean = newCalcs.mean;

        var improvement = ((newMean - oldMean) / oldMean * 100);

        var confidence = -1;

        // Check if there is enough data to calculate the calculate the p-value
        if (oldCalcs.size > 1 && newCalcs.size > 1) {
          // Perform a statistics test to see of there actually is a difference
          // in performance
          var ttest = new TTest(oldCalcs, newCalcs);
          var pValue = ttest.pValue();
          if (pValue < 0.001)
            confidence = 3;
          else if (pValue < 0.01)
            confidence = 2;
          else if (pValue < 0.05)
            confidence = 1;
          else
            confidence = 0;
        }

        results.push([
          category,
          benchmarkName,
          config,
          confidence,
          improvement,
        ]);
      }
    }

    return results;
  });

  compareRuntimes = makeCompareFn(function(oldData, newData) {
    oldData = oldData.times;
    newData = newData.times;

    var totalDiff;
    var diffs = [];
    var oldTotal = 0;
    var categories = Object.keys(oldData);
    for (var i = 0; i < categories.length; ++i) {
      var category = categories[i];
      if (category[0] === '_')
        continue;

      var oldTime = oldData[category];
      if (typeof oldTime !== 'string')
        continue;

      oldTime = toSecs(oldTime);
      oldTotal += oldTime;

      var newTime = newData[category];
      if (typeof newTime !== 'string')
        continue;

      newTime = toSecs(newTime);
      totalDiff = newTime - oldTime;
      totalDiff = (totalDiff < 0 ? '-' : '+')
                  + formatHMSTime(Math.abs(totalDiff));
      diffs.push([category, totalDiff]);
    }

    var newTotal = 0;
    categories = Object.keys(newData);
    for (var i = 0; i < categories.length; ++i) {
      var category = categories[i];
      if (category[0] === '_')
        continue;

      var newTime = newData[category];
      if (typeof newTime !== 'string')
        continue;

      newTotal += toSecs(newTime);
    }

    totalDiff = newTotal - oldTotal;
    totalDiff = (totalDiff < 0 ? '-' : '+')
                + formatHMSTime(Math.abs(totalDiff));
    return [diffs, totalDiff];
  });
})();
