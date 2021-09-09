module StringMap = Map.Make(String);

let addPointsForExtra = (getMetricValue, threshold, points, metricsMap) => {
  StringMap.fold(
    (key, metric, map) => {
      switch (getMetricValue(metric)) {
      | Some(metricValue) =>
        metricValue > threshold
          ? StringMap.add(key, points * (metricValue - threshold), map) : map
      | None => map
      }
    },
    metricsMap,
    StringMap.empty,
  );
};

let addPointsToUsersWithAtleastN =
    (getMetricValue, threshold, points, metricsMap) => {
  StringMap.fold(
    (key, metric, map) => {
      switch (getMetricValue(metric)) {
      | Some(metricValue) =>
        metricValue >= threshold ? StringMap.add(key, points, map) : map
      | None => map
      }
    },
    metricsMap,
    StringMap.empty,
  );
};

let applyTopNPoints =
    (threshholdPointsList, metricsMap, getMetricValue, compareFunc) => {
  let metricsArray = Array.of_list(StringMap.bindings(metricsMap));
  let f = ((_, metricValue1), (_, metricValue2)) => {
    compareFunc(getMetricValue(metricValue1), getMetricValue(metricValue2));
  };

  Array.sort(f, metricsArray);
  Belt.Array.reverseInPlace(metricsArray);

  metricsArray
  |> Array.iteri((index, metric) => {
       Js.log("index: " ++ string_of_int(index));
       Js.log("metric: ");
       Js.log(metric);
       Js.log("\n");
     });

  let counter = ref(0);
  let topNArrayWithPoints =
    metricsArray
    |> Array.mapi((i, (username, metric)) => {
         metric
         ->getMetricValue
         ->Belt.Option.mapWithDefault((username, 0), challengeMetric =>
             if (counter^ >= Array.length(threshholdPointsList)) {
               (username, 0);
             } else {
               let (place, points) = threshholdPointsList[counter^];
               if (i < Array.length(metricsArray) - 1) {
                 let (_, nextMetric) = metricsArray[i + 1];

                 nextMetric
                 ->getMetricValue
                 ->Belt.Option.mapWithDefault((), nextChallengeMetric =>
                     if (challengeMetric !== nextChallengeMetric && i >= place) {
                       counter := counter^ + 1;
                     }
                   );
               };
               (username, points);
             }
           )
       });

  Belt.Array.keep(topNArrayWithPoints, ((_, points)) => {points != 0})
  |> Array.fold_left(
       (map, (userPublicKey, userPoints)) => {
         StringMap.add(userPublicKey, userPoints, map)
       },
       StringMap.empty,
     );
};

// Combines a list of maps of users to points and returns one map of users to points
let sumPointsMaps = maps => {
  maps
  |> List.fold_left(
       StringMap.merge((_, value, secondValue) => {
         switch (value, secondValue) {
         | (Some(value), Some(secondValue)) => Some(value + secondValue)
         | (Some(value), None)
         | (None, Some(value)) => Some(value)
         | (None, None) => None
         }
       }),
       StringMap.empty,
     );
};
