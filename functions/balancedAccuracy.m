function pi = balancedAccuracy(predLabels,trueLabels)
% BALANCEDACCURACY calculates the balanced accuracy of a set of
% pseudo-labels given the true labels.

    Y = unique(trueLabels);
    pi = 0;
    for i = 1:length(Y)
        y = find(trueLabels==Y(i));
        pi = pi + 0.5 * length(intersect(y,find(predLabels==Y(i))))/length(y);
    end
end

