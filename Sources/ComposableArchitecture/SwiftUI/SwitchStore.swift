import CasePaths
import Combine
import SwiftUI

// MARK: Domain

enum AppState: Equatable {
  case featureOne(FeatureState)
  case featureTwo(FeatureState)
  case featureThree(FeatureState)
}

enum AppAction: Equatable {
  case featureOne(FeatureAction)
  case featureTwo(FeatureAction)
  case featureThree(FeatureAction)
  case toggleFeatureOne
  case toggleFeatureTwo
  case toggleFeatureThree
}

struct FeatureState: Equatable {
  let title: String
}

enum FeatureAction: Equatable {
    case someAction
}

let appReducer = Reducer<AppState, AppAction, Void> { state, action, _ in
  switch action {
  case .toggleFeatureOne:
    state = .featureOne(.init(title: "Feature One"))
  case .toggleFeatureTwo:
    state = .featureTwo(.init(title: "Feature Two"))
  case .toggleFeatureThree:
    state = .featureThree(.init(title: "Feature Three"))
  default:
    break
  }
  return .none
}.debug()

// MARK: Feature Views

struct FeatureView: View {
  let store: Store<FeatureState, FeatureAction>

  var body: some View {
    WithViewStore(store) { Text($0.title) }
  }
}

// MARK: SwitchStore

public struct SwitchStore<State, Action, Cases>: View where State: Equatable {
  let caseStore: CaseStore<State, Action>
  let content: TupleView<Cases>

  private init(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    @ViewBuilder _ content: () -> TupleView<Cases>
  ) {
    self.caseStore = CaseStore(store, removeDuplicates: isDuplicate)
    self.content = content()
  }

  public var body: some View {
    content.environmentObject(caseStore)
  }
}

extension SwitchStore where State: Equatable {
  private init(
    _ store: Store<State, Action>,
    @ViewBuilder _ content: () -> TupleView<Cases>
  ) {
    self.init(store, removeDuplicates: ==, content)
  }
}

public extension SwitchStore {
  init<
    StateA, ActionA, ContentA
  >(
    _ store: Store<State, Action>,
    @ViewBuilder content: () -> Cases
  )
  where Cases == CaseLet<State, Action, StateA, ActionA, ContentA> {
    self.init(store, { TupleView(content()) })
  }

  init<
    StateA, ActionA, ContentA,
    StateB, ActionB, ContentB
  >(
    _ store: Store<State, Action>,
    @ViewBuilder content: () -> TupleView<Cases>
  )
  where Cases == (
    CaseLet<State, Action, StateA, ActionA, ContentA>,
    CaseLet<State, Action, StateB, ActionB, ContentB>
  ) {
    self.init(store) { content() }
  }

  init<
    StateA, ActionA, ContentA,
    StateB, ActionB, ContentB,
    StateC, ActionC, ContentC
  >(
    _ store: Store<State, Action>,
    @ViewBuilder content: () -> TupleView<Cases>
  )
  where Cases == (
    CaseLet<State, Action, StateA, ActionA, ContentA>,
    CaseLet<State, Action, StateB, ActionB, ContentB>,
    CaseLet<State, Action, StateC, ActionC, ContentC>
  ) {
    self.init(store) { content() }
  }
}

class CaseStore<State, Action>: ObservableObject {
  private let store: Store<State, Action>
  private let publisher: StorePublisher<State>
  private var caseCancellable: AnyCancellable?

  // N.B. `ViewStore` does not use a `@Published` property, so `objectWillChange`
  // won't be synthesized automatically. To work around issues on iOS 13 we explicitly declare it.
  public private(set) lazy var objectWillChange = ObservableObjectPublisher()

  /// Initializes a view store from a store.
  ///
  /// - Parameters:
  ///   - store: A store.
  ///   - isDuplicate: A function to determine when two `State` values are equal. When values are
  ///     equal, repeat view computations are removed.St
  public init(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool
  ) {
    self.store = store
    let publisher = store.state.removeDuplicates(by: isDuplicate)
    self.publisher = StorePublisher(publisher)
    self.caseCancellable = publisher.sink { [weak self] _ in
      self?.objectWillChange.send()
    }
  }

  func ifCase<LocalState, LocalAction, Result>(
    state path: OptionalPath<State, LocalState>,
    action fromLocalAction: @escaping (LocalAction) -> Action,
    transform: (Store<LocalState, LocalAction>) -> Result
  ) -> Result? {
    path.extract(from: store.state.value).map { state in
      transform(store.scope(state: { _ in state }, action: fromLocalAction))
    }
  }
}

extension CaseStore where State: Equatable {
  convenience init(_ store: Store<State, Action>) {
    self.init(store, removeDuplicates: ==)
  }
}

public struct CaseLet<
  GlobalState,
  GlobalAction,
  LocalState,
  LocalAction,
  Content
>: View where Content: View {
  @EnvironmentObject
  var caseStore: CaseStore<GlobalState, GlobalAction>

  let toLocalState: CasePath<GlobalState, LocalState>
  let fromLocalAction: (LocalAction) -> GlobalAction
  let content: (Store<LocalState, LocalAction>) -> Content

  public init(
    state toLocalState: CasePath<GlobalState, LocalState>,
    action fromLocalAction: @escaping (LocalAction) -> GlobalAction,
    then content: @escaping (Store<LocalState, LocalAction>) -> Content
  ) {
    self.toLocalState = toLocalState
    self.fromLocalAction = fromLocalAction
    self.content = content
  }

  public var body: some View {
    caseStore.ifCase(
      state: OptionalPath(toLocalState),
      action: fromLocalAction,
      transform: content
    )
  }
}

// MARK: Example View

struct FeaturesView_SwitchCaseLet: View {
  let store: Store<AppState, AppAction>
  let delayedAction: AppAction

  init(store: Store<AppState, AppAction>, afterDelaySend action: AppAction) {
    self.store = store
    self.delayedAction = action
  }

  var body: some View {
    SwitchStore(store) {
      CaseLet(
        state: /AppState.featureOne,
        action: AppAction.featureOne,
        then: FeatureView.init(store:)
      )
      CaseLet(
        state: /AppState.featureTwo,
        action: AppAction.featureTwo,
        then: FeatureView.init(store:)
      )
      CaseLet(
        state: /AppState.featureThree,
        action: AppAction.featureThree,
        then: FeatureView.init(store:)
      )
    }
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        ViewStore(store).send(delayedAction)
      }
    }
  }
}

// MARK: Previews

struct ExclusiveFeatureState_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      FeaturesView_SwitchCaseLet(
        store: Store(
          initialState: .featureOne(.init(title: "Feature One")),
          reducer: appReducer,
          environment: ()
        ),
        afterDelaySend: .toggleFeatureTwo
      )
      FeaturesView_SwitchCaseLet(
        store: Store(
          initialState: .featureTwo(.init(title: "Feature Two")),
          reducer: appReducer,
          environment: ()
        ),
        afterDelaySend: .toggleFeatureThree
      )
      FeaturesView_SwitchCaseLet(
        store: Store(
          initialState: .featureThree(.init(title: "Feature Three")),
          reducer: appReducer,
          environment: ()
        ),
        afterDelaySend: .toggleFeatureOne
      )
    }
  }
}
