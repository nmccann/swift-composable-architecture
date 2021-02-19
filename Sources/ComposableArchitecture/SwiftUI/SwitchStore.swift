import SwiftUI

// MARK: Domain

enum ExclusiveFeaturesState {
  case featureOne(FeatureOneState)
  case featureTwo(FeatureTwoState)
}

struct FeatureOneState: Equatable {
  let title = "Feature One"
}

struct FeatureTwoState: Equatable {
  let title = "Feature Two"
}

// MARK: Feature Views

struct FeatureOneView: View {
  let store: Store<FeatureOneState, Never>

  var body: some View {
    WithViewStore(store) { Text($0.title) }
  }
}

struct FeatureTwoView: View {
  let store: Store<FeatureTwoState, Never>

  var body: some View {
    WithViewStore(store) { Text($0.title) }
  }
}

// MARK: Using IfLetStore

struct ExclusiveFeatureView_IfLet: View {
  let store: Store<ExclusiveFeaturesState, Void>

  var body: some View {
    Group {
      IfLetStore(
        store.scope(state: /ExclusiveFeaturesState.featureOne).actionless,
        then: FeatureOneView.init(store:)
      )
      IfLetStore(
        store.scope(state: /ExclusiveFeaturesState.featureTwo).actionless,
        then: FeatureTwoView.init(store:)
      )
    }
  }
}

// MARK: Using SwitchStore

struct ExclusiveFeatureView_SwitchLet: View {
  let store: Store<ExclusiveFeaturesState, Void>

  var body: some View {
    Group {
      IfLetStore(
        store.scope(state: /ExclusiveFeaturesState.featureOne).actionless,
        then: FeatureOneView.init(store:)
      )
      IfLetStore(
        store.scope(state: /ExclusiveFeaturesState.featureTwo).actionless,
        then: FeatureTwoView.init(store:)
      )
    }
  }
}

// MARK: Previews

struct ExclusiveFeatureState_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      ExclusiveFeatureView_IfLet(
        store: Store(
          initialState: .featureOne(.init()),
          reducer: .empty,
          environment: ()
        )
      )
      ExclusiveFeatureView_IfLet(
        store: Store(
          initialState: .featureTwo(.init()),
          reducer: .empty,
          environment: ()
        )
      )
      ExclusiveFeatureView_SwitchLet(
        store: Store(
          initialState: .featureOne(.init()),
          reducer: .empty,
          environment: ()
        )
      )
      ExclusiveFeatureView_SwitchLet(
        store: Store(
          initialState: .featureTwo(.init()),
          reducer: .empty,
          environment: ()
        )
      )
    }
  }
}
